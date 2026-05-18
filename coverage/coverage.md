Compiling 142 files with Solc 0.8.33
Solc 0.8.33 finished in 27.40s
Compiler run successful with warnings:
Warning (2018): Function state mutability can be restricted to view
  --> test/fork/GovernanceFork.t.sol:90:5:
   |
90 |     function test_Fork_GovernanceDeploysOnSepolia() public {
   |     ^ (Relevant source part starts here and spans across multiple lines).

Warning (2018): Function state mutability can be restricted to view
   --> test/fork/RealProtocolFork.t.sol:101:5:
    |
101 |     function test_Fork_ChainlinkFeed_ReturnsValidPrice() public {
    |     ^ (Relevant source part starts here and spans across multiple lines).

Analysing contracts...
Running tests...

Ran 3 tests for test/fork/GovernanceFork.t.sol:GovernanceForkTest
[PASS] test_Fork_FullLifecycleOnSepolia() (gas: 3091)
[PASS] test_Fork_GovernanceDeploysOnSepolia() (gas: 3252)
[PASS] test_Fork_TimelockControlsTreasury() (gas: 3045)
Suite result: ok. 3 passed; 0 failed; 0 skipped; finished in 15.65ms (3.77ms CPU time)

Ran 3 tests for test/fork/RealProtocolFork.t.sol:RealProtocolForkTest
[PASS] test_Fork_ChainlinkFeed_ReturnsValidPrice() (gas: 3302)
[PASS] test_Fork_ChainlinkFeed_StalenessRevertsCorrectly() (gas: 3210)
[PASS] test_Fork_USDC_AMMPool_AddLiquidityAndSwap() (gas: 3164)
Suite result: ok. 3 passed; 0 failed; 0 skipped; finished in 17.93ms (6.79ms CPU time)

Ran 5 tests for test/unit/ItemRegistry.t.sol:ItemRegistryTest
[PASS] test_BurnerCanBurnItems() (gas: 128675)
[PASS] test_InvalidResourceIdReverts() (gas: 19962)
[PASS] test_MintBatchMintsMultipleItems() (gas: 217731)
[PASS] test_MintEquipmentCreditsBalance() (gas: 104554)
[PASS] test_MintResourceCreditsBalance() (gas: 107275)
Suite result: ok. 5 passed; 0 failed; 0 skipped; finished in 25.49ms (14.59ms CPU time)

Ran 10 tests for test/unit/SecurityAccessControl.t.sol:SecurityAccessControlTest
[PASS] test_Fixed_AdminSetAtConstruction() (gas: 14110)
[PASS] test_Fixed_AttackerCannotGrantOwnRole() (gas: 22960)
[PASS] test_Fixed_AuthorisedMinterCanMint() (gas: 83917)
[PASS] test_Fixed_MintToZeroAddressReverts() (gas: 53365)
[PASS] test_Fixed_MintZeroAmountReverts() (gas: 55802)
[PASS] test_Fixed_UnauthorisedMintReverts() (gas: 24155)
[PASS] test_Vuln_AnyoneCanMint() (gas: 41531)
[PASS] test_Vuln_AnyoneCanSetAdmin() (gas: 47718)
[PASS] test_Vuln_AttackerClaimsAdmin() (gas: 40918)
[PASS] test_Vuln_AttackerMintsForOthers() (gas: 43440)
Suite result: ok. 10 passed; 0 failed; 0 skipped; finished in 16.66ms (12.12ms CPU time)

Ran 10 tests for test/unit/ChainlinkPriceAdapter.t.sol:ChainlinkPriceAdapterTest
[PASS] test_AdminCanUpdateFeed() (gas: 681710)
[PASS] test_AdminCanUpdateMaxStaleness() (gas: 51915)
[PASS] test_LatestPriceReturnsCorrectValue() (gas: 28119)
[PASS] test_LatestPriceUintReturnsUint() (gas: 24045)
[PASS] test_NegativePriceReverts() (gas: 38329)
[PASS] test_NonAdminCannotUpdateFeed() (gas: 661616)
[PASS] test_PriceAtStalenessThresholdDoesNotRevert() (gas: 34644)
[PASS] test_PriceUpdateReflectedImmediately() (gas: 38312)
[PASS] test_StalePriceReverts() (gas: 34834)
[PASS] test_ZeroPriceReverts() (gas: 33057)
Suite result: ok. 10 passed; 0 failed; 0 skipped; finished in 41.09ms (19.68ms CPU time)

Ran 5 tests for test/unit/SecurityReentrancy.t.sol:SecurityReentrancyTest
[PASS] test_Fixed_LegitimateWithdrawWorks() (gas: 67470)
[PASS] test_Fixed_ReentrancyBlocked() (gas: 473323)
[PASS] test_Fixed_ReentrantCallReverts() (gas: 42127)
[PASS] test_Vuln_ReentrancyDrainsPool() (gas: 603593)
[PASS] test_Vuln_StateUpdateAfterCall() (gas: 39011)
Suite result: ok. 5 passed; 0 failed; 0 skipped; finished in 7.87ms (4.72ms CPU time)

Ran 23 tests for test/unit/GameParameters.t.sol:GameParametersTest
[PASS] test_upgrade_PreservesV1Storage() (gas: 2536516)
[PASS] test_upgrade_UnauthorisedRevertsForAttacker() (gas: 2472547)
[PASS] test_upgrade_V2InitializerCannotRunTwice() (gas: 2550518)
[PASS] test_upgrade_V2InitializerSetsNewParams() (gas: 2551063)
[PASS] test_upgrade_V2VersionString() (gas: 2487198)
[PASS] test_v1_DefaultValues() (gas: 38082)
[PASS] test_v1_ImplementationCannotBeInitialised() (gas: 2140499)
[PASS] test_v1_Pause_BlocksSetters() (gas: 53950)
[PASS] test_v1_Pause_RevertsForNonPauser() (gas: 20985)
[PASS] test_v1_SetArenaEntryFee_RevertsOnZero() (gas: 23769)
[PASS] test_v1_SetArenaEntryFee_Success() (gas: 33358)
[PASS] test_v1_SetLootDropRates_RevertsForNonManager() (gas: 21268)
[PASS] test_v1_SetLootDropRates_RevertsWhenSumExceedsBPS() (gas: 24744)
[PASS] test_v1_SetLootDropRates_Success() (gas: 40797)
[PASS] test_v1_SetMaxCraftingIngredients_RevertsOnZero() (gas: 23493)
[PASS] test_v1_SetMaxCraftingIngredients_Success() (gas: 33080)
[PASS] test_v1_SetTreasuryFeeBps_RevertsAbove10000() (gas: 24826)
[PASS] test_v1_SetTreasuryFeeBps_Success() (gas: 32757)
[PASS] test_v1_Unpause_ResumesSetters() (gas: 51107)
[PASS] test_v1_Version() (gas: 17353)
[PASS] test_v2_SetCraftingDiscount_RevertsAboveBPS() (gas: 2559286)
[PASS] test_v2_SetCraftingDiscount_Success() (gas: 2562381)
[PASS] test_v2_SetWinStreakBonus_Success() (gas: 2562272)
Suite result: ok. 23 passed; 0 failed; 0 skipped; finished in 63.79ms (54.01ms CPU time)

Ran 20 tests for test/unit/AMMMarketplace.t.sol:AMMMarketplaceTest
[PASS] test_AddLiquidity_FirstDeposit_MintsLpAndUpdatesReserves() (gas: 2112685)
[PASS] test_AddLiquidity_RevertsOnSlippageTooHigh() (gas: 27798)
[PASS] test_AddLiquidity_RevertsOnZeroAmountA() (gas: 19924)
[PASS] test_AddLiquidity_RevertsOnZeroAmountB() (gas: 19622)
[PASS] test_AddLiquidity_SubsequentDeposit_MaintainsRatioAndMintsLP() (gas: 190553)
[PASS] test_Constructor_RevertsOnSameTokens() (gas: 112845)
[PASS] test_Constructor_RevertsOnZeroTokenA() (gas: 112219)
[PASS] test_Constructor_RevertsOnZeroTokenB() (gas: 112583)
[PASS] test_Constructor_SetsTokensAndLpMetadata() (gas: 37113)
[PASS] test_GetAmountOut_MatchesSwapOutput_BothDirections() (gas: 128446)
[PASS] test_RemoveLiquidity_ProportionalTokenReturn() (gas: 103082)
[PASS] test_RemoveLiquidity_RevertsOnMinASlippage() (gas: 31860)
[PASS] test_RemoveLiquidity_RevertsOnMinBSlippage() (gas: 31823)
[PASS] test_RemoveLiquidity_RevertsOnZeroLpAmount() (gas: 20205)
[PASS] test_Swap_FeeAccumulatesInKInvariant() (gas: 82950)
[PASS] test_Swap_RevertsOnInvalidToken() (gas: 24990)
[PASS] test_Swap_RevertsOnSlippage() (gas: 32549)
[PASS] test_Swap_RevertsOnZeroAmount() (gas: 22023)
[PASS] test_Swap_TokenAForTokenB_CorrectOutput() (gas: 97932)
[PASS] test_Swap_TokenBForTokenA_CorrectOutput() (gas: 94936)
Suite result: ok. 20 passed; 0 failed; 0 skipped; finished in 64.58ms (52.43ms CPU time)

Ran 22 tests for test/unit/MercenaryGuild.t.sol:MercenaryGuildTest
[PASS] test_CancelListing_ReturnsNFTAndCancelsState() (gas: 301233)
[PASS] test_CancelListing_RevertsIfRented() (gas: 565573)
[PASS] test_ClaimFees_PullsAccumulatedFeesAndResetsBalance() (gas: 574786)
[PASS] test_Constructor_RevertsOnFeeTooHigh() (gas: 81914)
[PASS] test_Constructor_RevertsOnZeroAdmin() (gas: 69981)
[PASS] test_Constructor_RevertsOnZeroFeeRecipient() (gas: 69608)
[PASS] test_Constructor_RevertsOnZeroPaymentToken() (gas: 69397)
[PASS] test_Constructor_SetsStateCorrectly() (gas: 36211)
[PASS] test_List_ERC1155_TransfersItemsAndCreatesListing() (gas: 326573)
[PASS] test_List_ERC721_TransfersNFTAndCreatesListing() (gas: 283205)
[PASS] test_List_RevertsOnInvalidDuration() (gas: 58880)
[PASS] test_List_RevertsOnZeroPrice() (gas: 57216)
[PASS] test_ReclaimExpired_RevertsIfNotExpired() (gas: 570427)
[PASS] test_ReclaimExpired_RevertsIfNotLender() (gas: 572261)
[PASS] test_ReclaimExpired_SucceedsAfterEndTime() (gas: 517786)
[PASS] test_Rent_DeductsFeeAndMarketsListing() (gas: 586465)
[PASS] test_Rent_ProtocolFeeForwardedToRecipient() (gas: 573205)
[PASS] test_Rent_RevertsIfAlreadyRented() (gas: 632691)
[PASS] test_Rent_RevertsIfDurationOutOfRange() (gas: 280642)
[PASS] test_Rent_RevertsIfListingNotFound() (gas: 22770)
[PASS] test_ReturnEarly_ReturnsNFTToLenderAndRelistsListing() (gas: 519061)
[PASS] test_ReturnEarly_RevertsIfNotBorrower() (gas: 568196)
Suite result: ok. 22 passed; 0 failed; 0 skipped; finished in 76.16ms (63.93ms CPU time)

Ran 10 tests for test/unit/Governance.t.sol:GovernanceTest
[PASS] test_BelowThresholdCannotPropose() (gas: 43360)
[PASS] test_CancelProposal_WhilePending() (gas: 126635)
[PASS] test_FullGovernanceLifecycle() (gas: 388378)
[PASS] test_GovernorParameters() (gas: 27056)
[PASS] test_ProposalBecomesActiveAfterDelay() (gas: 99614)
[PASS] test_ProposalCreated() (gas: 97345)
[PASS] test_ProposalNeedsQueuing() (gas: 92875)
[PASS] test_ProposalSucceeds() (gas: 192080)
[PASS] test_TimelockDelay() (gas: 9888)
[PASS] test_VotesAreCastCorrectly() (gas: 252299)
Suite result: ok. 10 passed; 0 failed; 0 skipped; finished in 39.14ms (29.81ms CPU time)

Ran 23 tests for test/unit/PvPArena.t.sol:PvPArenaTest
[PASS] test_Cancel_RefundsBothPlayersAfterWindow() (gas: 634910)
[PASS] test_Cancel_ReleasesHeroFromBattleLock() (gas: 623925)
[PASS] test_Cancel_RevertIfNotMatchedState() (gas: 374986)
[PASS] test_Cancel_RevertIfWindowNotElapsed() (gas: 656528)
[PASS] test_ClaimReward_RevertIfAlreadyClaimed() (gas: 726430)
[PASS] test_ClaimReward_RevertIfBattleNotResolved() (gas: 372023)
[PASS] test_ClaimReward_RevertIfNotWinner() (gas: 747636)
[PASS] test_ClaimReward_TreasuryCutSentOnResolve() (gas: 739698)
[PASS] test_ClaimReward_WinnerReceivesCorrectAmount() (gas: 727640)
[PASS] test_Pause_BlocksRegister() (gas: 192958)
[PASS] test_Register_OpensSlotForFirstPlayer() (gas: 373302)
[PASS] test_Register_RevertIfHeroAlreadyInBattle() (gas: 373427)
[PASS] test_Register_RevertIfNotHeroOwner() (gas: 201069)
[PASS] test_Register_RevertIfSamePlayer() (gas: 451032)
[PASS] test_Register_RevertWhenPaused() (gas: 192337)
[PASS] test_Register_SecondPlayerMatchesAndFiresVRF() (gas: 660553)
[PASS] test_Register_TransfersEntryFee() (gas: 368617)
[PASS] test_SetEntryFee_RevertIfNotAdmin() (gas: 16530)
[PASS] test_SetEntryFee_RevertIfZero() (gas: 16556)
[PASS] test_SetEntryFee_UpdatesValue() (gas: 25342)
[PASS] test_SetTreasuryFeeBps_RevertIfAboveMax() (gas: 17246)
[PASS] test_StateMachine_FulfillOnCancelledBattleIsNoOp() (gas: 638430)
[PASS] test_Unpause_AllowsRegister() (gas: 378017)
Suite result: ok. 23 passed; 0 failed; 0 skipped; finished in 109.21ms (93.08ms CPU time)

Ran 14 tests for test/unit/HeroNFT.t.sol:HeroNFTTest
[PASS] test_AnyoneCanMintHero() (gas: 174216)
[PASS] test_FactoryDeployCreate() (gas: 394217)
[PASS] test_FactoryDeployCreate2DeterministicAddress() (gas: 420198)
[PASS] test_GetHeroAttributes_RevertsOnNonexistentToken() (gas: 20198)
[PASS] test_ImplementationInitializersDisabled() (gas: 21362)
[PASS] test_LevelUpIncrementsLevel() (gas: 177131)
[PASS] test_LevelUp_RevertsAtMaxLevel() (gas: 177609)
[PASS] test_LevelUp_RevertsOnNonexistentToken() (gas: 24758)
[PASS] test_MintHero_MintsStarterAeth() (gas: 169703)
[PASS] test_MintHero_RevertsOnZeroAddress() (gas: 19658)
[PASS] test_NonUpgraderCannotUpgrade() (gas: 3377143)
[PASS] test_ProxyInitializesCorrectly() (gas: 47986)
[PASS] test_SupportsInterface() (gas: 15448)
[PASS] test_TokenURI_ContainsBaseURI() (gas: 169176)
Suite result: ok. 14 passed; 0 failed; 0 skipped; finished in 826.21ms (36.25ms CPU time)

Ran 3 tests for test/fuzz/GuildTreasuryFuzz.t.sol:GuildTreasuryFuzzTest
[PASS] testFuzz_ConvertToSharesMonotone(uint256,uint256) (runs: 1000, μ: 28853, ~: 28799)
[PASS] testFuzz_DepositRedeemRoundTrip(uint256) (runs: 1000, μ: 190654, ~: 190784)
[PASS] testFuzz_InflationAttackUnprofitable(uint256,uint256) (runs: 1000, μ: 307419, ~: 307776)
Suite result: ok. 3 passed; 0 failed; 0 skipped; finished in 1.18s (2.98s CPU time)

Ran 17 tests for test/gas/BattleMathBench.t.sol:BattleMathBench
[PASS] testFuzz_battlePower_YulMatchesSolidity(uint16,uint16,uint16,uint16,uint256) (runs: 1000, μ: 4613, ~: 3973)
[PASS] testFuzz_clampedSub_YulMatchesSolidity(uint256,uint256) (runs: 1000, μ: 1196, ~: 1186)
[PASS] testFuzz_sqrt_FloorProperty(uint256) (runs: 1000, μ: 6056, ~: 4850)
[PASS] testFuzz_sqrt_YulMatchesSolidity(uint256) (runs: 1000, μ: 21616, ~: 15288)
[PASS] test_GasBenchmark_battlePower() (gas: 12325)
[PASS] test_GasBenchmark_clampedSub() (gas: 10746)
[PASS] test_GasBenchmark_sqrt() (gas: 29390)
[PASS] test_battlePower_AllZeros_returnsZero() (gas: 1970)
[PASS] test_battlePower_MaxRandMod_includesFullAgi() (gas: 2050)
[PASS] test_battlePower_SolidityAndYul_returnSameValue() (gas: 2893)
[PASS] test_battlePower_ZeroRandMod_returnsBaseScore() (gas: 3332)
[PASS] test_clampedSub_Equal_ReturnsZero() (gas: 1128)
[PASS] test_clampedSub_Normal() (gas: 983)
[PASS] test_clampedSub_Underflow_ReturnsZero() (gas: 1537)
[PASS] test_sqrt_EdgeCases() (gas: 6002)
[PASS] test_sqrt_ResultIsFloor() (gas: 242731)
[PASS] test_sqrt_SolidityAndYul_returnSameValue() (gas: 80146)
Suite result: ok. 17 passed; 0 failed; 0 skipped; finished in 1.20s (803.97ms CPU time)

Ran 11 tests for test/unit/GuildTreasury.t.sol:GuildTreasuryTest
[PASS] test_Constructor_RevertsOnZeroAdmin() (gas: 95213)
[PASS] test_DepositMintsShares() (gas: 134606)
[PASS] test_InjectYield_RevertsOnZeroAmount() (gas: 16357)
[PASS] test_MaxWithdrawEqualsDepositedAmount() (gas: 136741)
[PASS] test_NonYieldManagerCannotInjectYield() (gas: 89569)
[PASS] test_PreviewDepositMatchesActual() (gas: 134225)
[PASS] test_RedeemReturnsAssets() (gas: 143608)
[PASS] test_SupportsInterface() (gas: 6675)
[PASS] test_TwoDepositorsGetProportionalShares() (gas: 196793)
[PASS] test_VaultMetadata() (gas: 34777)
[PASS] test_YieldInjectionRaisesSharePrice() (gas: 183220)
Suite result: ok. 11 passed; 0 failed; 0 skipped; finished in 1.20s (37.77ms CPU time)

Ran 23 tests for test/unit/CraftingEngine.t.sol:CraftingEngineTest
[PASS] testFuzz_craft_ActualCostMatchesPreview(uint256) (runs: 1000, μ: 600665, ~: 600837)
[PASS] testFuzz_craft_TreasuryReceivesCorrectFee(uint256,uint256) (runs: 1000, μ: 502631, ~: 504014)
[PASS] test_addRecipe_RevertsForNonAdmin() (gas: 19728)
[PASS] test_addRecipe_RevertsOnLengthMismatch() (gas: 19711)
[PASS] test_addRecipe_RevertsOnZeroOutputAmount() (gas: 19954)
[PASS] test_addRecipe_SuccessByAdmin() (gas: 280598)
[PASS] test_craft_FreeRecipe_NoAethCharged() (gas: 309043)
[PASS] test_craft_HappyPath_MintsOutputAndBurnsInputs() (gas: 565297)
[PASS] test_craft_RevertsOnInsufficientAethAllowance() (gas: 339014)
[PASS] test_craft_RevertsOnInsufficientIngredient() (gas: 337626)
[PASS] test_craft_RevertsOnRemovedRecipe() (gas: 270051)
[PASS] test_craft_RevertsOnUnknownRecipe() (gas: 24462)
[PASS] test_craft_RevertsWhenPaused() (gas: 309527)
[PASS] test_pause_RevertsForNonPauser() (gas: 16374)
[PASS] test_previewAethCost_ChangeWithOraclePrice() (gas: 303551)
[PASS] test_previewAethCost_ReturnsCorrectAmount() (gas: 292687)
[PASS] test_removeRecipe_RevertsOnAlreadyInactive() (gas: 261090)
[PASS] test_removeRecipe_Success() (gas: 266377)
[PASS] test_setRecipeCost_RevertsForNonAdmin() (gas: 277494)
[PASS] test_setRecipeCost_UpdatesValue() (gas: 287839)
[PASS] test_setTreasuryFeeBps_RevertsAboveMax() (gas: 17035)
[PASS] test_setTreasuryFeeBps_UpdatesValue() (gas: 25115)
[PASS] test_unpause_ResumesNormalOperation() (gas: 550439)
Suite result: ok. 23 passed; 0 failed; 0 skipped; finished in 1.21s (1.96s CPU time)

Ran 1 test for test/invariant/AethTokenInvariant.t.sol:AethTokenInvariantTest
[PASS] invariant_TotalSupplyEqualsMintsMinusBurns() (runs: 500, calls: 25000, reverts: 0)

╭------------------+----------+-------+---------+----------╮
| Contract         | Selector | Calls | Reverts | Discards |
+==========================================================+
| AethTokenHandler | burn     | 12387 | 0       | 0        |
|------------------+----------+-------+---------+----------|
| AethTokenHandler | mint     | 12613 | 0       | 0        |
╰------------------+----------+-------+---------+----------╯

Suite result: ok. 1 passed; 0 failed; 0 skipped; finished in 7.40s (7.39s CPU time)

Ran 7 tests for test/unit/AethToken.t.sol:AethTokenTest
[PASS] test_BurnMoreThanBalanceReverts() (gas: 77743)
[PASS] test_BurnerCanBurn() (gas: 91971)
[PASS] test_DelegateUpdatesVotingPower() (gas: 142200)
[PASS] test_InitialSupplyMintedToAdmin() (gas: 16421)
[PASS] test_MinterCanMint() (gas: 72409)
[PASS] test_NonMinterCannotMint() (gas: 17425)
[PASS] test_PermitAllowsGaslessApproval() (gas: 128893)
Suite result: ok. 7 passed; 0 failed; 0 skipped; finished in 11.71s (27.26ms CPU time)

Ran 2 tests for test/invariant/AMMInvariant.t.sol:AMMInvariantTest
[PASS] invariant_KNeverDecreases() (runs: 500, calls: 25000, reverts: 0)

╭------------+-----------------+-------+---------+----------╮
| Contract   | Selector        | Calls | Reverts | Discards |
+===========================================================+
| AMMHandler | addLiquidity    | 6264  | 0       | 0        |
|------------+-----------------+-------+---------+----------|
| AMMHandler | removeLiquidity | 6242  | 0       | 0        |
|------------+-----------------+-------+---------+----------|
| AMMHandler | swapAforB       | 6204  | 0       | 0        |
|------------+-----------------+-------+---------+----------|
| AMMHandler | swapBforA       | 6290  | 0       | 0        |
╰------------+-----------------+-------+---------+----------╯

[PASS] invariant_TotalSupplyGtMinimumLiquidity() (runs: 500, calls: 25000, reverts: 0)

╭------------+-----------------+-------+---------+----------╮
| Contract   | Selector        | Calls | Reverts | Discards |
+===========================================================+
| AMMHandler | addLiquidity    | 6264  | 0       | 0        |
|------------+-----------------+-------+---------+----------|
| AMMHandler | removeLiquidity | 6242  | 0       | 0        |
|------------+-----------------+-------+---------+----------|
| AMMHandler | swapAforB       | 6204  | 0       | 0        |
|------------+-----------------+-------+---------+----------|
| AMMHandler | swapBforA       | 6290  | 0       | 0        |
╰------------+-----------------+-------+---------+----------╯

Suite result: ok. 2 passed; 0 failed; 0 skipped; finished in 11.75s (23.42s CPU time)

Ran 2 tests for test/invariant/GuildTreasuryInvariant.t.sol:GuildTreasuryInvariantTest
[PASS] invariant_SharePriceNeverDecreases() (runs: 500, calls: 25000, reverts: 0)

╭----------------------+-------------+-------+---------+----------╮
| Contract             | Selector    | Calls | Reverts | Discards |
+=================================================================+
| GuildTreasuryHandler | deposit     | 6193  | 0       | 0        |
|----------------------+-------------+-------+---------+----------|
| GuildTreasuryHandler | injectYield | 6362  | 0       | 0        |
|----------------------+-------------+-------+---------+----------|
| GuildTreasuryHandler | redeem      | 6231  | 0       | 0        |
|----------------------+-------------+-------+---------+----------|
| GuildTreasuryHandler | withdraw    | 6214  | 0       | 0        |
╰----------------------+-------------+-------+---------+----------╯

[PASS] invariant_TotalAssetsGeConvertedShares() (runs: 500, calls: 25000, reverts: 0)

╭----------------------+-------------+-------+---------+----------╮
| Contract             | Selector    | Calls | Reverts | Discards |
+=================================================================+
| GuildTreasuryHandler | deposit     | 6193  | 0       | 0        |
|----------------------+-------------+-------+---------+----------|
| GuildTreasuryHandler | injectYield | 6362  | 0       | 0        |
|----------------------+-------------+-------+---------+----------|
| GuildTreasuryHandler | redeem      | 6231  | 0       | 0        |
|----------------------+-------------+-------+---------+----------|
| GuildTreasuryHandler | withdraw    | 6214  | 0       | 0        |
╰----------------------+-------------+-------+---------+----------╯

Suite result: ok. 2 passed; 0 failed; 0 skipped; finished in 12.46s (24.14s CPU time)

Ran 3 tests for test/fuzz/AMMFuzz.t.sol:AMMFuzzTest
[PASS] testFuzz_AddLiquidityProportionalShares(uint256) (runs: 1000, μ: 200146, ~: 200261)
[PASS] testFuzz_GetAmountOutMatchesActualSwap(uint256) (runs: 1000, μ: 132440, ~: 131992)
[PASS] testFuzz_SwapNeverViolatesKInvariant(uint256) (runs: 1000, μ: 124707, ~: 124260)
Suite result: ok. 3 passed; 0 failed; 0 skipped; finished in 12.46s (14.28s CPU time)

Ran 21 test suites in 12.47s (61.88s CPU time): 217 tests passed, 0 failed, 0 skipped (217 total tests)

╭---------------------------------------------+------------------+-------------------+------------------+------------------╮
| File                                        | % Lines          | % Statements      | % Branches       | % Funcs          |
+==========================================================================================================================+
| contracts/arena/PvPArena.sol                | 84.57% (137/162) | 83.63% (143/171)  | 60.87% (14/23)   | 85.71% (18/21)   |
|---------------------------------------------+------------------+-------------------+------------------+------------------|
| contracts/assembly/BattleMath.sol           | 50.00% (16/32)   | 36.84% (14/38)    | 75.00% (3/4)     | 100.00% (6/6)    |
|---------------------------------------------+------------------+-------------------+------------------+------------------|
| contracts/crafting/CraftingEngine.sol       | 91.84% (90/98)   | 82.05% (96/117)   | 48.28% (14/29)   | 91.67% (11/12)   |
|---------------------------------------------+------------------+-------------------+------------------+------------------|
| contracts/governance/AetherGovernor.sol     | 100.00% (22/22)  | 95.83% (23/24)    | 0.00% (0/1)      | 100.00% (10/10)  |
|---------------------------------------------+------------------+-------------------+------------------+------------------|
| contracts/governance/AetherTimelock.sol     | 100.00% (3/3)    | 100.00% (2/2)     | 100.00% (0/0)    | 100.00% (1/1)    |
|---------------------------------------------+------------------+-------------------+------------------+------------------|
| contracts/marketplace/AMMMarketplace.sol    | 97.50% (78/80)   | 97.30% (108/111)  | 95.45% (21/22)   | 100.00% (6/6)    |
|---------------------------------------------+------------------+-------------------+------------------+------------------|
| contracts/nft/HeroNFT.sol                   | 88.89% (32/36)   | 89.74% (35/39)    | 80.00% (4/5)     | 100.00% (9/9)    |
|---------------------------------------------+------------------+-------------------+------------------+------------------|
| contracts/nft/HeroNFTFactory.sol            | 89.66% (26/29)   | 89.19% (33/37)    | 0.00% (0/4)      | 100.00% (5/5)    |
|---------------------------------------------+------------------+-------------------+------------------+------------------|
| contracts/nft/ItemRegistry.sol              | 87.80% (36/41)   | 65.52% (38/58)    | 6.67% (1/15)     | 80.00% (8/10)    |
|---------------------------------------------+------------------+-------------------+------------------+------------------|
| contracts/oracle/ChainlinkPriceAdapter.sol  | 88.57% (31/35)   | 76.92% (30/39)    | 18.18% (2/11)    | 100.00% (5/5)    |
|---------------------------------------------+------------------+-------------------+------------------+------------------|
| contracts/oracle/MockAggregator.sol         | 76.92% (20/26)   | 82.35% (14/17)    | 100.00% (0/0)    | 66.67% (6/9)     |
|---------------------------------------------+------------------+-------------------+------------------+------------------|
| contracts/proxy/GameParametersV1.sol        | 77.55% (38/49)   | 74.42% (32/43)    | 80.00% (4/5)     | 90.91% (10/11)   |
|---------------------------------------------+------------------+-------------------+------------------+------------------|
| contracts/proxy/GameParametersV2.sol        | 90.48% (19/21)   | 86.96% (20/23)    | 25.00% (1/4)     | 100.00% (4/4)    |
|---------------------------------------------+------------------+-------------------+------------------+------------------|
| contracts/rental/MercenaryGuild.sol         | 81.74% (94/115)  | 76.81% (106/138)  | 56.25% (18/32)   | 70.59% (12/17)   |
|---------------------------------------------+------------------+-------------------+------------------+------------------|
| contracts/security/AccessVuln.sol           | 100.00% (18/18)  | 100.00% (13/13)   | 0.00% (0/8)      | 100.00% (5/5)    |
|---------------------------------------------+------------------+-------------------+------------------+------------------|
| contracts/security/ReentrancyVuln.sol       | 100.00% (20/20)  | 100.00% (16/16)   | 0.00% (0/8)      | 100.00% (6/6)    |
|---------------------------------------------+------------------+-------------------+------------------+------------------|
| contracts/token/AethToken.sol               | 100.00% (17/17)  | 73.68% (14/19)    | 0.00% (0/5)      | 100.00% (5/5)    |
|---------------------------------------------+------------------+-------------------+------------------+------------------|
| contracts/vault/GuildTreasury.sol           | 100.00% (11/11)  | 100.00% (10/10)   | 100.00% (2/2)    | 100.00% (4/4)    |
|---------------------------------------------+------------------+-------------------+------------------+------------------|
| test/fork/RealProtocolFork.t.sol            | 0.00% (0/2)      | 0.00% (0/1)       | 100.00% (0/0)    | 0.00% (0/1)      |
|---------------------------------------------+------------------+-------------------+------------------+------------------|
| test/fuzz/AMMFuzz.t.sol                     | 100.00% (2/2)    | 100.00% (1/1)     | 100.00% (0/0)    | 100.00% (1/1)    |
|---------------------------------------------+------------------+-------------------+------------------+------------------|
| test/invariant/AMMInvariant.t.sol           | 100.00% (39/39)  | 95.00% (38/40)    | 71.43% (5/7)     | 100.00% (5/5)    |
|---------------------------------------------+------------------+-------------------+------------------+------------------|
| test/invariant/AethTokenInvariant.t.sol     | 100.00% (18/18)  | 100.00% (22/22)   | 100.00% (5/5)    | 100.00% (4/4)    |
|---------------------------------------------+------------------+-------------------+------------------+------------------|
| test/invariant/GuildTreasuryInvariant.t.sol | 100.00% (38/38)  | 100.00% (40/40)   | 100.00% (6/6)    | 100.00% (5/5)    |
|---------------------------------------------+------------------+-------------------+------------------+------------------|
| test/unit/AMMMarketplace.t.sol              | 100.00% (2/2)    | 100.00% (1/1)     | 100.00% (0/0)    | 100.00% (1/1)    |
|---------------------------------------------+------------------+-------------------+------------------+------------------|
| test/unit/MercenaryGuild.t.sol              | 100.00% (7/7)    | 100.00% (4/4)     | 100.00% (0/0)    | 100.00% (3/3)    |
|---------------------------------------------+------------------+-------------------+------------------+------------------|
| test/unit/PvPArena.t.sol                    | 100.00% (8/8)    | 100.00% (8/8)     | 0.00% (0/2)      | 100.00% (2/2)    |
|---------------------------------------------+------------------+-------------------+------------------+------------------|
| test/unit/SecurityReentrancy.t.sol          | 100.00% (22/22)  | 100.00% (19/19)   | 42.86% (3/7)     | 100.00% (7/7)    |
|---------------------------------------------+------------------+-------------------+------------------+------------------|
| Total                                       | 88.56% (844/953) | 83.73% (880/1051) | 50.24% (103/205) | 90.86% (159/175) |
╰---------------------------------------------+------------------+-------------------+------------------+------------------╯
