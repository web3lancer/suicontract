#[test_only]
module web3lancer::user_profile_tests {
    use sui::test_scenario;
    use sui::tx_context::TxContext;
    use web3lancer::user_profile;

    #[test]
    fun test_init_profile_registry() {
        let mut ctx = test_scenario::new_tx_context();
        user_profile::init(&mut ctx);
        // If no abort, test passes
    }
}
