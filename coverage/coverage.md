Compiling 141 files with Solc 0.8.33
Solc 0.8.33 finished in 32.63s
Compiler run successful with warnings:
Warning (2018): Function state mutability can be restricted to view
  --> test/fork/GovernanceFork.t.sol:90:5:
   |
90 |     function test_Fork_GovernanceDeploysOnSepolia() public {
   |     ^ (Relevant source part starts here and spans across multiple lines).

Analysing contracts...
Running tests...

Ran 3 tests for test/fork/GovernanceFork.t.sol:GovernanceForkTest
[PASS] test_Fork_FullLifecycleOnSepolia() (gas: 3091)
[PASS] test_Fork_GovernanceDeploysOnSepolia() (gas: 3252)
[PASS] test_Fork_TimelockControlsTreasury() (gas: 3045)
Suite result: ok. 3 passed; 0 failed; 0 skipped; finished in 25.30ms (5.98ms CPU time)

Ran 5 tests for test/unit/SecurityReentrancy.t.sol:SecurityReentrancyTest
[PASS] test_Fixed_LegitimateWithdrawWorks() (gas: 67470)
[PASS] test_Fixed_ReentrancyBlocked() (gas: 473323)
[PASS] test_Fixed_ReentrantCallReverts() (gas: 42127)
[PASS] test_Vuln_ReentrancyDrainsPool() (gas: 603593)
[PASS] test_Vuln_StateUpdateAfterCall() (gas: 39011)
Suite result: ok. 5 passed; 0 failed; 0 skipped; finished in 34.99ms (15.42ms CPU time)

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
Suite result: ok. 10 passed; 0 failed; 0 skipped; finished in 43.11ms (23.43ms CPU time)

Ran 10 tests for test/unit/ChainlinkPriceAdapter.t.sol:ChainlinkPriceAdapterTest
[PASS] test_AdminCanUpdateFeed() (gas: 681627)
[PASS] test_AdminCanUpdateMaxStaleness() (gas: 51832)
[PASS] test_LatestPriceReturnsCorrectValue() (gas: 28036)
[PASS] test_LatestPriceUintReturnsUint() (gas: 23962)
[PASS] test_NegativePriceReverts() (gas: 38246)
[PASS] test_NonAdminCannotUpdateFeed() (gas: 661616)
[PASS] test_PriceAtStalenessThresholdDoesNotRevert() (gas: 34561)
[PASS] test_PriceUpdateReflectedImmediately() (gas: 38229)
[PASS] test_StalePriceReverts() (gas: 34751)
[PASS] test_ZeroPriceReverts() (gas: 32974)
Suite result: ok. 10 passed; 0 failed; 0 skipped; finished in 44.90ms (25.32ms CPU time)

Ran 5 tests for test/unit/ItemRegistry.t.sol:ItemRegistryTest
[PASS] test_BurnerCanBurnItems() (gas: 127378)
[PASS] test_InvalidResourceIdReverts() (gas: 19962)
[PASS] test_MintBatchMintsMultipleItems() (gas: 213363)
[PASS] test_MintEquipmentCreditsBalance() (gas: 103257)
[PASS] test_MintResourceCreditsBalance() (gas: 106001)
Suite result: ok. 5 passed; 0 failed; 0 skipped; finished in 47.37ms (22.76ms CPU time)

Ran 7 tests for test/unit/AethToken.t.sol:AethTokenTest
[PASS] test_BurnMoreThanBalanceReverts() (gas: 77743)
[PASS] test_BurnerCanBurn() (gas: 91971)
[PASS] test_DelegateUpdatesVotingPower() (gas: 142200)
[PASS] test_InitialSupplyMintedToAdmin() (gas: 16421)
[PASS] test_MinterCanMint() (gas: 72409)
[PASS] test_NonMinterCannotMint() (gas: 17425)
[PASS] test_PermitAllowsGaslessApproval() (gas: 128893)
Suite result: ok. 7 passed; 0 failed; 0 skipped; finished in 69.05ms (47.80ms CPU time)

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
Suite result: ok. 11 passed; 0 failed; 0 skipped; finished in 62.15ms (54.72ms CPU time)

Ran 23 tests for test/unit/GameParameters.t.sol:GameParametersTest
[PASS] test_upgrade_PreservesV1Storage() (gas: 2524688)
[PASS] test_upgrade_UnauthorisedRevertsForAttacker() (gas: 2460719)
[PASS] test_upgrade_V2InitializerCannotRunTwice() (gas: 2537800)
[PASS] test_upgrade_V2InitializerSetsNewParams() (gas: 2538345)
[PASS] test_upgrade_V2VersionString() (gas: 2475370)
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
[PASS] test_v2_SetCraftingDiscount_RevertsAboveBPS() (gas: 2546568)
[PASS] test_v2_SetCraftingDiscount_Success() (gas: 2549663)
[PASS] test_v2_SetWinStreakBonus_Success() (gas: 2549554)
Suite result: ok. 23 passed; 0 failed; 0 skipped; finished in 111.26ms (86.46ms CPU time)

Ran 10 tests for test/unit/Governance.t.sol:GovernanceTest
[PASS] test_BelowThresholdCannotPropose() (gas: 43212)
[PASS] test_CancelProposal_WhilePending() (gas: 126463)
[PASS] test_FullGovernanceLifecycle() (gas: 388116)
[PASS] test_GovernorParameters() (gas: 27056)
[PASS] test_ProposalBecomesActiveAfterDelay() (gas: 99442)
[PASS] test_ProposalCreated() (gas: 97173)
[PASS] test_ProposalNeedsQueuing() (gas: 92703)
[PASS] test_ProposalSucceeds() (gas: 191872)
[PASS] test_TimelockDelay() (gas: 9888)
[PASS] test_VotesAreCastCorrectly() (gas: 252091)
Suite result: ok. 10 passed; 0 failed; 0 skipped; finished in 85.97ms (68.38ms CPU time)

Ran 20 tests for test/unit/AMMMarketplace.t.sol:AMMMarketplaceTest
[PASS] test_AddLiquidity_FirstDeposit_MintsLpAndUpdatesReserves() (gas: 2174667)
[PASS] test_AddLiquidity_RevertsOnSlippageTooHigh() (gas: 27792)
[PASS] test_AddLiquidity_RevertsOnZeroAmountA() (gas: 19924)
[PASS] test_AddLiquidity_RevertsOnZeroAmountB() (gas: 19622)
[PASS] test_AddLiquidity_SubsequentDeposit_MaintainsRatioAndMintsLP() (gas: 190530)
[PASS] test_Constructor_RevertsOnSameTokens() (gas: 112882)
[PASS] test_Constructor_RevertsOnZeroTokenA() (gas: 112256)
[PASS] test_Constructor_RevertsOnZeroTokenB() (gas: 112620)
[PASS] test_Constructor_SetsTokensAndLpMetadata() (gas: 37113)
[PASS] test_GetAmountOut_MatchesSwapOutput_BothDirections() (gas: 128082)
[PASS] test_RemoveLiquidity_ProportionalTokenReturn() (gas: 103082)
[PASS] test_RemoveLiquidity_RevertsOnMinASlippage() (gas: 31860)
[PASS] test_RemoveLiquidity_RevertsOnMinBSlippage() (gas: 31823)
[PASS] test_RemoveLiquidity_RevertsOnZeroLpAmount() (gas: 20205)
[PASS] test_Swap_FeeAccumulatesInKInvariant() (gas: 82768)
[PASS] test_Swap_RevertsOnInvalidToken() (gas: 24990)
[PASS] test_Swap_RevertsOnSlippage() (gas: 32549)
[PASS] test_Swap_RevertsOnZeroAmount() (gas: 22023)
[PASS] test_Swap_TokenAForTokenB_CorrectOutput() (gas: 97750)
[PASS] test_Swap_TokenBForTokenA_CorrectOutput() (gas: 94754)
Suite result: ok. 20 passed; 0 failed; 0 skipped; finished in 164.16ms (92.93ms CPU time)

Ran 13 tests for test/unit/HeroNFT.t.sol:HeroNFTTest
[PASS] test_FactoryDeployCreate() (gas: 368459)
[PASS] test_FactoryDeployCreate2DeterministicAddress() (gas: 370310)
[PASS] test_GetHeroAttributes_RevertsOnNonexistentToken() (gas: 20152)
[PASS] test_ImplementationInitializersDisabled() (gas: 18785)
[PASS] test_LevelUpIncrementsLevel() (gas: 121284)
[PASS] test_LevelUp_RevertsAtMaxLevel() (gas: 915772)
[PASS] test_LevelUp_RevertsOnNonexistentToken() (gas: 24712)
[PASS] test_MintHero_RevertsOnZeroAddress() (gas: 19612)
[PASS] test_MinterCanMintHero() (gas: 120645)
[PASS] test_NonUpgraderCannotUpgrade() (gas: 3270821)
[PASS] test_ProxyInitializesCorrectly() (gas: 47871)
[PASS] test_SupportsInterface() (gas: 15425)
[PASS] test_TokenURI_ContainsBaseURI() (gas: 115352)
Suite result: ok. 13 passed; 0 failed; 0 skipped; finished in 85.85ms (71.96ms CPU time)

Ran 23 tests for test/unit/PvPArena.t.sol:PvPArenaTest
[PASS] test_Cancel_RefundsBothPlayersAfterWindow() (gas: 582862)
[PASS] test_Cancel_ReleasesHeroFromBattleLock() (gas: 571877)
[PASS] test_Cancel_RevertIfNotMatchedState() (gas: 343042)
[PASS] test_Cancel_RevertIfWindowNotElapsed() (gas: 610103)
[PASS] test_ClaimReward_RevertIfAlreadyClaimed() (gas: 679913)
[PASS] test_ClaimReward_RevertIfBattleNotResolved() (gas: 340102)
[PASS] test_ClaimReward_RevertIfNotWinner() (gas: 701142)
[PASS] test_ClaimReward_TreasuryCutSentOnResolve() (gas: 693250)
[PASS] test_ClaimReward_WinnerReceivesCorrectAmount() (gas: 681123)
[PASS] test_Pause_BlocksRegister() (gas: 151734)
[PASS] test_Register_OpensSlotForFirstPlayer() (gas: 341381)
[PASS] test_Register_RevertIfHeroAlreadyInBattle() (gas: 341506)
[PASS] test_Register_RevertIfNotHeroOwner() (gas: 205416)
[PASS] test_Register_RevertIfSamePlayer() (gas: 404837)
[PASS] test_Register_RevertWhenPaused() (gas: 151113)
[PASS] test_Register_SecondPlayerMatchesAndFiresVRF() (gas: 614128)
[PASS] test_Register_TransfersEntryFee() (gas: 336719)
[PASS] test_SetEntryFee_RevertIfNotAdmin() (gas: 16507)
[PASS] test_SetEntryFee_RevertIfZero() (gas: 16533)
[PASS] test_SetEntryFee_UpdatesValue() (gas: 25319)
[PASS] test_SetTreasuryFeeBps_RevertIfAboveMax() (gas: 17223)
[PASS] test_StateMachine_FulfillOnCancelledBattleIsNoOp() (gas: 586359)
[PASS] test_Unpause_AllowsRegister() (gas: 346073)
Suite result: ok. 23 passed; 0 failed; 0 skipped; finished in 212.78ms (185.10ms CPU time)

Ran 23 tests for test/unit/CraftingEngine.t.sol:CraftingEngineTest
[PASS] testFuzz_craft_ActualCostMatchesPreview(uint256) (runs: 1000, μ: 599979, ~: 600169)
[PASS] testFuzz_craft_TreasuryReceivesCorrectFee(uint256,uint256) (runs: 1000, μ: 502344, ~: 503680)
[PASS] test_addRecipe_RevertsForNonAdmin() (gas: 19728)
[PASS] test_addRecipe_RevertsOnLengthMismatch() (gas: 19711)
[PASS] test_addRecipe_RevertsOnZeroOutputAmount() (gas: 19954)
[PASS] test_addRecipe_SuccessByAdmin() (gas: 280598)
[PASS] test_craft_FreeRecipe_NoAethCharged() (gas: 308792)
[PASS] test_craft_HappyPath_MintsOutputAndBurnsInputs() (gas: 564963)
[PASS] test_craft_RevertsOnInsufficientAethAllowance() (gas: 338680)
[PASS] test_craft_RevertsOnInsufficientIngredient() (gas: 337375)
[PASS] test_craft_RevertsOnRemovedRecipe() (gas: 269549)
[PASS] test_craft_RevertsOnUnknownRecipe() (gas: 24462)
[PASS] test_craft_RevertsWhenPaused() (gas: 309527)
[PASS] test_pause_RevertsForNonPauser() (gas: 16374)
[PASS] test_previewAethCost_ChangeWithOraclePrice() (gas: 303217)
[PASS] test_previewAethCost_ReturnsCorrectAmount() (gas: 292353)
[PASS] test_removeRecipe_RevertsOnAlreadyInactive() (gas: 260588)
[PASS] test_removeRecipe_Success() (gas: 266126)
[PASS] test_setRecipeCost_RevertsForNonAdmin() (gas: 277494)
[PASS] test_setRecipeCost_UpdatesValue() (gas: 287588)
[PASS] test_setTreasuryFeeBps_RevertsAboveMax() (gas: 17035)
[PASS] test_setTreasuryFeeBps_UpdatesValue() (gas: 25115)
[PASS] test_unpause_ResumesNormalOperation() (gas: 550105)
Suite result: ok. 23 passed; 0 failed; 0 skipped; finished in 2.59s (4.36s CPU time)

Ran 17 tests for test/gas/BattleMathBench.t.sol:BattleMathBench
[PASS] testFuzz_battlePower_YulMatchesSolidity(uint16,uint16,uint16,uint16,uint256) (runs: 1000, μ: 4607, ~: 3973)
[PASS] testFuzz_clampedSub_YulMatchesSolidity(uint256,uint256) (runs: 1000, μ: 1196, ~: 1186)
[PASS] testFuzz_sqrt_FloorProperty(uint256) (runs: 1000, μ: 6050, ~: 4850)
[PASS] testFuzz_sqrt_YulMatchesSolidity(uint256) (runs: 1000, μ: 21566, ~: 15288)
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
Suite result: ok. 17 passed; 0 failed; 0 skipped; finished in 2.59s (1.52s CPU time)

Ran 3 tests for test/fuzz/AMMFuzz.t.sol:AMMFuzzTest
[PASS] testFuzz_AddLiquidityProportionalShares(uint256) (runs: 1000, μ: 200122, ~: 200238)
[PASS] testFuzz_GetAmountOutMatchesActualSwap(uint256) (runs: 1000, μ: 132292, ~: 131847)
[PASS] testFuzz_SwapNeverViolatesKInvariant(uint256) (runs: 1000, μ: 124560, ~: 124114)
Suite result: ok. 3 passed; 0 failed; 0 skipped; finished in 2.60s (7.25s CPU time)

Ran 3 tests for test/fuzz/GuildTreasuryFuzz.t.sol:GuildTreasuryFuzzTest
[PASS] testFuzz_ConvertToSharesMonotone(uint256,uint256) (runs: 1000, μ: 28882, ~: 28799)
[PASS] testFuzz_DepositRedeemRoundTrip(uint256) (runs: 1000, μ: 190657, ~: 190784)
[PASS] testFuzz_InflationAttackUnprofitable(uint256,uint256) (runs: 1000, μ: 307386, ~: 307728)
Suite result: ok. 3 passed; 0 failed; 0 skipped; finished in 2.60s (7.57s CPU time)

Ran 1 test for test/invariant/AethTokenInvariant.t.sol:AethTokenInvariantTest
[PASS] invariant_TotalSupplyEqualsMintsMinusBurns() (runs: 500, calls: 25000, reverts: 0)

╭------------------+----------+-------+---------+----------╮
| Contract         | Selector | Calls | Reverts | Discards |
+==========================================================+
| AethTokenHandler | burn     | 12387 | 0       | 0        |
|------------------+----------+-------+---------+----------|
| AethTokenHandler | mint     | 12613 | 0       | 0        |
╰------------------+----------+-------+---------+----------╯

Suite result: ok. 1 passed; 0 failed; 0 skipped; finished in 16.92s (16.91s CPU time)

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

Suite result: ok. 2 passed; 0 failed; 0 skipped; finished in 28.14s (55.38s CPU time)

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

Suite result: ok. 2 passed; 0 failed; 0 skipped; finished in 30.44s (59.02s CPU time)

Ran 22 tests for test/unit/MercenaryGuild.t.sol:MercenaryGuildTest
[PASS] test_CancelListing_ReturnsNFTAndCancelsState() (gas: 298039)
[PASS] test_CancelListing_RevertsIfRented() (gas: 565573)
[PASS] test_ClaimFees_PullsAccumulatedFeesAndResetsBalance() (gas: 574786)
[PASS] test_Constructor_RevertsOnFeeTooHigh() (gas: 81895)
[PASS] test_Constructor_RevertsOnZeroAdmin() (gas: 69962)
[PASS] test_Constructor_RevertsOnZeroFeeRecipient() (gas: 69589)
[PASS] test_Constructor_RevertsOnZeroPaymentToken() (gas: 69378)
[PASS] test_Constructor_SetsStateCorrectly() (gas: 36211)
[PASS] test_List_ERC1155_TransfersItemsAndCreatesListing() (gas: 323147)
[PASS] test_List_ERC721_TransfersNFTAndCreatesListing() (gas: 283205)
[PASS] test_List_RevertsOnInvalidDuration() (gas: 58880)
[PASS] test_List_RevertsOnZeroPrice() (gas: 57216)
[PASS] test_ReclaimExpired_RevertsIfNotExpired() (gas: 570427)
[PASS] test_ReclaimExpired_RevertsIfNotLender() (gas: 572261)
[PASS] test_ReclaimExpired_SucceedsAfterEndTime() (gas: 514592)
[PASS] test_Rent_DeductsFeeAndMarketsListing() (gas: 586465)
[PASS] test_Rent_ProtocolFeeForwardedToRecipient() (gas: 573205)
[PASS] test_Rent_RevertsIfAlreadyRented() (gas: 632691)
[PASS] test_Rent_RevertsIfDurationOutOfRange() (gas: 280642)
[PASS] test_Rent_RevertsIfListingNotFound() (gas: 22770)
[PASS] test_ReturnEarly_ReturnsNFTToLenderAndRelistsListing() (gas: 515611)
[PASS] test_ReturnEarly_RevertsIfNotBorrower() (gas: 568196)
Suite result: ok. 22 passed; 0 failed; 0 skipped; finished in 30.44s (147.57ms CPU time)

Ran 20 test suites in 30.46s (117.30s CPU time): 213 tests passed, 0 failed, 0 skipped (213 total tests)

╭---------------------------------------------+------------------+-------------------+------------------+------------------╮
| File                                        | % Lines          | % Statements      | % Branches       | % Funcs          |
+==========================================================================================================================+
| contracts/arena/PvPArena.sol                | 91.28% (136/149) | 90.45% (142/157)  | 70.00% (14/20)   | 90.00% (18/20)   |
|---------------------------------------------+------------------+-------------------+------------------+------------------|
| contracts/assembly/BattleMath.sol           | 50.00% (16/32)   | 36.84% (14/38)    | 75.00% (3/4)     | 100.00% (6/6)    |
|---------------------------------------------+------------------+-------------------+------------------+------------------|
| contracts/crafting/CraftingEngine.sol       | 91.40% (85/93)   | 83.49% (91/109)   | 52.00% (13/25)   | 91.67% (11/12)   |
|---------------------------------------------+------------------+-------------------+------------------+------------------|
| contracts/governance/AetherGovernor.sol     | 100.00% (20/20)  | 100.00% (20/20)   | 100.00% (0/0)    | 100.00% (10/10)  |
|---------------------------------------------+------------------+-------------------+------------------+------------------|
| contracts/governance/AetherTimelock.sol     | 100.00% (3/3)    | 100.00% (2/2)     | 100.00% (0/0)    | 100.00% (1/1)    |
|---------------------------------------------+------------------+-------------------+------------------+------------------|
| contracts/marketplace/AMMMarketplace.sol    | 96.63% (86/89)   | 96.67% (116/120)  | 87.50% (21/24)   | 100.00% (7/7)    |
|---------------------------------------------+------------------+-------------------+------------------+------------------|
| contracts/nft/HeroNFT.sol                   | 90.91% (30/33)   | 88.57% (31/35)    | 80.00% (4/5)     | 100.00% (9/9)    |
|---------------------------------------------+------------------+-------------------+------------------+------------------|
| contracts/nft/HeroNFTFactory.sol            | 100.00% (25/25)  | 90.32% (28/31)    | 0.00% (0/3)      | 100.00% (5/5)    |
|---------------------------------------------+------------------+-------------------+------------------+------------------|
| contracts/nft/ItemRegistry.sol              | 87.80% (36/41)   | 65.52% (38/58)    | 6.67% (1/15)     | 80.00% (8/10)    |
|---------------------------------------------+------------------+-------------------+------------------+------------------|
| contracts/oracle/ChainlinkPriceAdapter.sol  | 93.55% (29/31)   | 80.00% (28/35)    | 22.22% (2/9)     | 100.00% (5/5)    |
|---------------------------------------------+------------------+-------------------+------------------+------------------|
| contracts/oracle/MockAggregator.sol         | 76.92% (20/26)   | 82.35% (14/17)    | 100.00% (0/0)    | 66.67% (6/9)     |
|---------------------------------------------+------------------+-------------------+------------------+------------------|
| contracts/proxy/GameParametersV1.sol        | 77.55% (38/49)   | 74.42% (32/43)    | 80.00% (4/5)     | 90.91% (10/11)   |
|---------------------------------------------+------------------+-------------------+------------------+------------------|
| contracts/proxy/GameParametersV2.sol        | 90.48% (19/21)   | 86.96% (20/23)    | 25.00% (1/4)     | 100.00% (4/4)    |
|---------------------------------------------+------------------+-------------------+------------------+------------------|
| contracts/rental/MercenaryGuild.sol         | 81.58% (93/114)  | 77.21% (105/136)  | 58.06% (18/31)   | 70.59% (12/17)   |
|---------------------------------------------+------------------+-------------------+------------------+------------------|
| contracts/security/AccessVuln.sol           | 100.00% (18/18)  | 100.00% (13/13)   | 0.00% (0/8)      | 100.00% (5/5)    |
|---------------------------------------------+------------------+-------------------+------------------+------------------|
| contracts/security/ReentrancyVuln.sol       | 100.00% (20/20)  | 100.00% (16/16)   | 0.00% (0/8)      | 100.00% (6/6)    |
|---------------------------------------------+------------------+-------------------+------------------+------------------|
| contracts/token/AethToken.sol               | 100.00% (17/17)  | 73.68% (14/19)    | 0.00% (0/5)      | 100.00% (5/5)    |
|---------------------------------------------+------------------+-------------------+------------------+------------------|
| contracts/vault/GuildTreasury.sol           | 100.00% (11/11)  | 100.00% (10/10)   | 100.00% (2/2)    | 100.00% (4/4)    |
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
| Total                                       | 90.30% (838/928) | 85.25% (867/1017) | 52.31% (102/195) | 91.95% (160/174) |
╰---------------------------------------------+------------------+-------------------+------------------+------------------╯
