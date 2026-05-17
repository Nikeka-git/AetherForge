// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { AethToken } from "../../contracts/token/AethToken.sol";

/**
 * @title AethTokenHandler
 * @notice Foundry invariant handler for AethToken.
 *         Exposes mint and burn so the fuzzer can call them via targetContract.
 *
 * Accounting
 * ──────────
 * The handler keeps its own running tallies of totalMinted and totalBurned.
 * The invariant then checks that:
 *
 *     token.totalSupply() == INITIAL_SUPPLY + totalMinted - totalBurned
 *
 * This proves that no tokens are created or destroyed except through the
 * authorised mint() / burn() paths — the "total supply conservation" invariant
 * required by the assignment (Section 3.3).
 */
contract AethTokenHandler is Test {
    AethToken public token;

    address internal alice = makeAddr("alice_token");
    address internal bob = makeAddr("bob_token");
    address internal carol = makeAddr("carol_token");

    // Running totals tracked by the handler
    uint256 public totalMinted;
    uint256 public totalBurned;

    constructor(AethToken _token) {
        token = _token;
    }

    // Mint

    /**
     * @dev Mint 'amount' tokens to a pseudo-random actor.
     *      The handler itself holds MINTER_ROLE, so it can call token.mint().
     */
    function mint(uint256 amount, uint8 actorSeed) external {
        address actor = _pickActor(actorSeed);
        // Cap to a realistic upper bound to avoid overflow in the invariant math
        amount = bound(amount, 1, 10_000_000 * 1e18);

        try token.mint(actor, amount) {
            totalMinted += amount;
        } catch { }
    }

    // Burn

    /**
     * @dev Burn 'amount' tokens from an actor.
     *      Only burns up to the actor's actual balance so the call succeeds.
     */
    function burn(uint256 amount, uint8 actorSeed) external {
        address actor = _pickActor(actorSeed);
        uint256 balance = token.balanceOf(actor);
        if (balance == 0) return;

        amount = bound(amount, 1, balance);

        try token.burn(actor, amount) {
            totalBurned += amount;
        } catch { }
    }

    // Helpers

    function _pickActor(uint8 seed) internal view returns (address) {
        if (seed % 3 == 0) return alice;
        if (seed % 3 == 1) return bob;
        return carol;
    }
}

/**
 * @title AethTokenInvariantTest
 * @notice Invariant test for total supply conservation in AethToken.
 *
 * Invariant
 * ─────────
 * invariant_TotalSupplyEqualsMintsMinusBurns
 *     At all times:
 *         totalSupply == INITIAL_SUPPLY + handler.totalMinted - handler.totalBurned
 *
 *     This verifies that no tokens are silently created or destroyed.
 *     Every change to totalSupply must be traceable to an explicit mint() or
 *     burn() call routed through the handler — satisfying the "total supply
 *     conservation" requirement of Section 3.3 of the assignment.
 *
 * Run: forge test --match-contract AethTokenInvariantTest -vv
 */
contract AethTokenInvariantTest is Test {
    AethToken token;
    AethTokenHandler handler;

    uint256 internal constant INITIAL_SUPPLY = 100_000_000 * 1e18;

    function setUp() public {
        address admin = makeAddr("admin_token_inv");
        token = new AethToken(admin);

        handler = new AethTokenHandler(token);

        // Grant the handler both MINTER_ROLE and BURNER_ROLE so it can call
        // token.mint() and token.burn() directly.
        vm.startPrank(admin);
        token.grantRole(token.MINTER_ROLE(), address(handler));
        token.grantRole(token.BURNER_ROLE(), address(handler));
        vm.stopPrank();

        targetContract(address(handler));
    }

    // Invariant

    /**
     * @notice token.totalSupply() must always equal
     *         INITIAL_SUPPLY + totalMinted - totalBurned.
     *
     * Any discrepancy would indicate tokens being minted or burned outside the
     * authorised code paths, which constitutes a critical supply-integrity bug.
     */
    function invariant_TotalSupplyEqualsMintsMinusBurns() public view {
        uint256 expectedSupply = INITIAL_SUPPLY + handler.totalMinted() - handler.totalBurned();
        assertEq(
            token.totalSupply(), expectedSupply, "AethToken: totalSupply diverged from INITIAL_SUPPLY + minted - burned"
        );
    }
}
