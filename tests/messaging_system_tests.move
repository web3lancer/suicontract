#[test_only]
module web3lancer::messaging_system_tests {
    use sui::test_scenario;
    use sui::tx_context::TxContext;
    use web3lancer::messaging_system;

    #[test]
    fun test_init_messaging_registry() {
        let mut ctx = test_scenario::new_tx_context();
        messaging_system::init(&mut ctx);
        // If no abort, test passes
    }
}
