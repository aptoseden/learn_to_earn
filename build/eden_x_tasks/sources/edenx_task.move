module edenx::edenx_task {

    use aptos_framework::account::SignerCapability;
    use std::signer;
    use aptos_std::table::Table;
    use aptos_std::table;
    use std::error;
    use aptos_framework::aptos_account;
    use aptos_framework::resource_account;
    use aptos_framework::account;


    const INTRGRAL: u128 = 10;

    const NO_PERMISSION: u64 = 1000;

    const INVALID_ARGUMENT: u64 = 1001;

    const TASK_ID_ALREADY_EXISTS: u64 = 1002;

    const NOLOGIN_ACCOUNT: u64 = 1003;

    const TASK_ALREADY_EXISTS: u64 = 1004;

    const TASK_IS_END: u64 = 1005;

    const ENOT_AUTHORIZED: u64 = 1;

    struct Task has store, drop, copy {
        task_id: u64,
        task_code: u64,
        participants_amount: u32,
        counter: u32,
        award_amount: u32,
        on_off: u8
    }

    struct Participant has store, key {
        user_address: address,
        tasks: Table<u64, UserTasksList>
    }

    struct UserTasksList has store, drop, copy {
        task_id: u64,
        is_full: u8
    }

    struct TaskList has store, key {
        tasks: Table<u64, Task>
    }

    struct ModuleData has key {
        // Storing the signer capability here, so the module can programmatically sign for transactions
        signer_cap: SignerCapability,
    }

    struct CheckTaskStatusValue has store, key {
        is_open: bool,
        tasks: Task
    }

    fun init_module(resource_signer: &signer) {

        let resource_signer_cap = resource_account::retrieve_resource_account_cap(resource_signer, @eden_tasks);
        move_to(resource_signer, TaskList {
            tasks: table::new()
        });

        move_to(resource_signer, ModuleData {
            signer_cap: resource_signer_cap
        });
    }

    //    create Task
    public entry fun create_task(
        caller: &signer,
        _task_id: u64,
        _task_code: u64,
        _participants_amount: u32,
        _award_amount: u32
    ) acquires TaskList {

        // let owner = signer::address_of(resource_signer);

        // assert!(owner == @eden_tasks, error::permission_denied(NO_PERMISSION));

        let caller_address = signer::address_of(caller);
        // Abort if the caller is not the admin of this module.
        assert!(caller_address == @admin_addr, error::permission_denied(ENOT_AUTHORIZED));

        let task_list = borrow_global_mut<TaskList>(@edenx);

        assert!(!table::contains(&task_list.tasks, _task_id), error::already_exists(TASK_ID_ALREADY_EXISTS));

        let task = Task {
            task_id: _task_id,
            task_code: _task_code,
            participants_amount: _participants_amount,
            counter: 0,
            award_amount: _award_amount,
            on_off: 0
        };

        table::upsert(&mut task_list.tasks, _task_id, task);
    }

    public entry fun accept_tasks(
        resource_signer: &signer,
        _task_id: u64
    ) acquires TaskList, Participant {

        let task_list = borrow_global_mut<TaskList>(@edenx);

        assert!(table::contains(&task_list.tasks, _task_id), error::invalid_argument(INVALID_ARGUMENT));

        let addrress = signer::address_of(resource_signer);

        if (!exists<Participant>(addrress)) {
            move_to(resource_signer, Participant {
                user_address: addrress,
                tasks: table::new()
            });

            let usertask = UserTasksList {
                task_id: _task_id,
                is_full: 0
            };
            let task_list = borrow_global_mut<Participant>(addrress);

            table::upsert(&mut task_list.tasks, _task_id, usertask);

        } else {
            let task_list = borrow_global_mut<Participant>(addrress);

            assert!(!table::contains(&task_list.tasks, _task_id), error::invalid_argument(INVALID_ARGUMENT));

            let usertask = UserTasksList {
                task_id: _task_id,
                is_full: 0
            };

            let task_list = borrow_global_mut<Participant>(addrress);
            table::upsert(&mut task_list.tasks, _task_id, usertask);

        }
    }

    public entry fun start_task(
        receive_signer: &signer,
        _task_id: u64,
        _task_code: u64
    ) acquires Participant, TaskList, ModuleData {
        let user_address = signer::address_of(receive_signer);

        assert!(exists<Participant>(user_address), error::permission_denied(NOLOGIN_ACCOUNT));

        let participant = borrow_global_mut<Participant>(user_address);

        assert!(participant.user_address == user_address, error::permission_denied(NO_PERMISSION));

        let task_list = borrow_global_mut<TaskList>(@edenx);

        assert!(table::contains(&task_list.tasks, _task_id), error::invalid_argument(INVALID_ARGUMENT));

        let tasks = table::borrow_mut(&mut task_list.tasks, _task_id);

        assert!(tasks.on_off == 0, error::invalid_state(TASK_IS_END));

        assert!(tasks.task_code == _task_code, error::invalid_state(TASK_IS_END));

        assert!(table::contains(&participant.tasks, _task_id), error::already_exists(TASK_ID_ALREADY_EXISTS));

        assert!(tasks.counter < tasks.participants_amount, error::permission_denied(NOLOGIN_ACCOUNT));

        let par_task = table::borrow_mut(&mut participant.tasks, _task_id);
        assert!(par_task.is_full == 0, error::invalid_state(TASK_IS_END));

        let moudle_data = borrow_global_mut<ModuleData>(@edenx);

        let resource_signer = account::create_signer_with_capability(&moudle_data.signer_cap);

        if ((tasks.counter + 1) == tasks.participants_amount) {
            tasks.on_off = 1;
            tasks.counter = tasks.counter + 1;
            par_task.is_full = 1;
            aptos_account::transfer(&resource_signer, user_address, 2*1000000);
        } else if ((tasks.counter + 1) < tasks.participants_amount) {
            tasks.counter = tasks.counter + 1;
            par_task.is_full = 1;
            aptos_account::transfer(&resource_signer, user_address, 2*1000000);
        };



    }

    #[view]
    public fun get_counter(_task_id: u64) :u32 acquires TaskList {
        // assert signer has created a list
        assert!(exists<TaskList>(@eden_tasks), error::invalid_argument(INVALID_ARGUMENT));
        // gets the TaskList resource
        let task_list = borrow_global_mut<TaskList>(@eden_tasks);
        let tasks = table::borrow(&mut task_list.tasks, _task_id);
        tasks.counter
    }

    #[view]
    public fun read_task(_task_id: u64) :Task acquires TaskList {
        // assert signer has created a list
        assert!(exists<TaskList>(@eden_tasks), error::invalid_argument(INVALID_ARGUMENT));
        // gets the TaskList resource
        let task_list = borrow_global_mut<TaskList>(@eden_tasks);
        *table::borrow(& task_list.tasks, _task_id)
    }


}
