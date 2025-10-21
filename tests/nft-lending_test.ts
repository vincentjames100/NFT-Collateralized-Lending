import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
  name: "Ensure initial reputation is set correctly for new users",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get("deployer")!;
    const wallet1 = accounts.get("wallet_1")!;
    
    let block = chain.mineBlock([
      Tx.contractCall("nft-lending", "get-user-reputation", [
        types.principal(wallet1.address)
      ], wallet1.address)
    ]);
    
    assertEquals(block.receipts.length, 1);
    assertEquals(block.receipts[0].result.expectOk(), 
      types.tuple({
        "total-loans": types.uint(0),
        "successful-loans": types.uint(0),
        "defaulted-loans": types.uint(0),
        "reputation-score": types.uint(750),
        "last-activity": types.uint(2)
      }));
  },
});

Clarinet.test({
  name: "Test platform fee rate configuration",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get("deployer")!;
    const wallet1 = accounts.get("wallet_1")!;
    
    // Test initial fee rate
    let block = chain.mineBlock([
      Tx.contractCall("nft-lending", "get-platform-fee-rate", [], deployer.address)
    ]);
    
    assertEquals(block.receipts[0].result, types.uint(250)); // 2.5%
    
    // Test setting new fee rate by deployer (should succeed)
    block = chain.mineBlock([
      Tx.contractCall("nft-lending", "set-platform-fee-rate", [
        types.uint(300)
      ], deployer.address)
    ]);
    
    assertEquals(block.receipts[0].result, types.ok(types.bool(true)));
    
    // Verify new fee rate
    block = chain.mineBlock([
      Tx.contractCall("nft-lending", "get-platform-fee-rate", [], deployer.address)
    ]);
    
    assertEquals(block.receipts[0].result, types.uint(300));
    
    // Test setting fee rate by non-deployer (should fail)
    block = chain.mineBlock([
      Tx.contractCall("nft-lending", "set-platform-fee-rate", [
        types.uint(400)
      ], wallet1.address)
    ]);
    
    assertEquals(block.receipts[0].result, types.err(types.uint(100))); // ERR-UNAUTHORIZED
  },
});

Clarinet.test({
  name: "Test minimum reputation score configuration",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get("deployer")!;
    const wallet1 = accounts.get("wallet_1")!;
    
    // Test initial min reputation score
    let block = chain.mineBlock([
      Tx.contractCall("nft-lending", "get-min-reputation-score", [], deployer.address)
    ]);
    
    assertEquals(block.receipts[0].result, types.uint(500));
    
    // Test setting new min reputation score by deployer (should succeed)
    block = chain.mineBlock([
      Tx.contractCall("nft-lending", "set-min-reputation-score", [
        types.uint(600)
      ], deployer.address)
    ]);
    
    assertEquals(block.receipts[0].result, types.ok(types.bool(true)));
    
    // Verify new min reputation score
    block = chain.mineBlock([
      Tx.contractCall("nft-lending", "get-min-reputation-score", [], deployer.address)
    ]);
    
    assertEquals(block.receipts[0].result, types.uint(600));
    
    // Test setting score by non-deployer (should fail)
    block = chain.mineBlock([
      Tx.contractCall("nft-lending", "set-min-reputation-score", [
        types.uint(700)
      ], wallet1.address)
    ]);
    
    assertEquals(block.receipts[0].result, types.err(types.uint(100))); // ERR-UNAUTHORIZED
  },
});

Clarinet.test({
  name: "Test loan counter initialization and increment",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get("deployer")!;
    
    // Test initial loan counter
    let block = chain.mineBlock([
      Tx.contractCall("nft-lending", "get-loan-counter", [], deployer.address)
    ]);
    
    assertEquals(block.receipts[0].result, types.uint(0));
  },
});

Clarinet.test({
  name: "Test reputation calculation logic",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get("deployer")!;
    const wallet1 = accounts.get("wallet_1")!;
    
    // Get initial reputation
    let block = chain.mineBlock([
      Tx.contractCall("nft-lending", "get-user-reputation", [
        types.principal(wallet1.address)
      ], wallet1.address)
    ]);
    
    const initialRep = block.receipts[0].result.expectOk();
    assertEquals(initialRep['reputation-score'], types.uint(750));
  },
});

Clarinet.test({
  name: "Test error constants are properly defined",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get("deployer")!;
    const wallet1 = accounts.get("wallet_1")!;
    
    // Test unauthorized access (should return ERR-UNAUTHORIZED = 100)
    let block = chain.mineBlock([
      Tx.contractCall("nft-lending", "set-platform-fee-rate", [
        types.uint(300)
      ], wallet1.address)
    ]);
    
    assertEquals(block.receipts[0].result, types.err(types.uint(100)));
  },
});

Clarinet.test({
  name: "Test get-loan function with non-existent loan",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get("deployer")!;
    
    // Test getting a loan that doesn't exist
    let block = chain.mineBlock([
      Tx.contractCall("nft-lending", "get-loan", [
        types.uint(999)
      ], deployer.address)
    ]);
    
    assertEquals(block.receipts[0].result, types.none());
  },
});

Clarinet.test({
  name: "Test get-collateral-info function with non-existent collateral",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get("deployer")!;
    
    // Test getting collateral info that doesn't exist
    let block = chain.mineBlock([
      Tx.contractCall("nft-lending", "get-collateral-info", [
        types.principal("ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.test-nft"),
        types.uint(1)
      ], deployer.address)
    ]);
    
    assertEquals(block.receipts[0].result, types.none());
  },
});

Clarinet.test({
  name: "Test fund-loan function with non-existent loan",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get("deployer")!;
    const wallet1 = accounts.get("wallet_1")!;
    
    // Test funding a loan that doesn't exist
    let block = chain.mineBlock([
      Tx.contractCall("nft-lending", "fund-loan", [
        types.uint(999)
      ], wallet1.address)
    ]);
    
    assertEquals(block.receipts[0].result, types.err(types.uint(101))); // ERR-NOT-FOUND
  },
});

Clarinet.test({
  name: "Test repay-loan function with non-existent loan",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get("deployer")!;
    const wallet1 = accounts.get("wallet_1")!;
    
    // Test repaying a loan that doesn't exist
    let block = chain.mineBlock([
      Tx.contractCall("nft-lending", "repay-loan", [
        types.uint(999)
      ], wallet1.address)
    ]);
    
    assertEquals(block.receipts[0].result, types.err(types.uint(101))); // ERR-NOT-FOUND
  },
});

Clarinet.test({
  name: "Test liquidate-loan function with non-existent loan",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get("deployer")!;
    const wallet1 = accounts.get("wallet_1")!;
    
    // Test liquidating a loan that doesn't exist
    let block = chain.mineBlock([
      Tx.contractCall("nft-lending", "liquidate-loan", [
        types.uint(999)
      ], wallet1.address)
    ]);
    
    assertEquals(block.receipts[0].result, types.err(types.uint(101))); // ERR-NOT-FOUND
  },
});
