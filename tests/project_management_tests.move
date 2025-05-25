#[test_only]
module web3lancer::project_management_tests {
    use sui::test_scenario;
    use sui::tx_context::TxContext;
    use web3lancer::project_management;

    #[test]
    fun test_init_project_registry() {
        let mut ctx = test_scenario::new_tx_context();
        project_management::init(&mut ctx);
        // If no abort, test passes
    }
}
