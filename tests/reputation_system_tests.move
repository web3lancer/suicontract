#[test_only]
module web3lancer::reputation_system_tests {
    use sui::test_scenario;
    use sui::tx_context::TxContext;
    use web3lancer::reputation_system;

    #[test]
    fun test_init_reputation_registry() {
        let mut ctx = test_scenario::new_tx_context();
        reputation_system::init(&mut ctx);
        // If no abort, test passes
    }
}
