# Compound Practice

Welcome to the Compound Practice repository! The main purpose of this repository is to provide a platform for everyone to practice using Compound Finance and gain familiarity with its operational principles.

## Exercise 1

Practice calling `mint` and `redeem` on cTokens, and simulate the accrual of interest on deposited funds over a period of time using Foundry's cheatcode.

## Environment Setup

To get started with the Compound Practice repository, follow the steps below:

1. Clone the repository:

   ```shell
   git clone git@github.com:Doge-is-Dope/Blockchain-Resource-Updated.git
   ```

2. Navigate to the Compound Practice directory:

   ```shell
   cd Blockchain-Resource/section3/CompoundPractice
   ```

3. Install the necessary dependencies:

   ```shell
   forge install
   ```

4. Build the project:

   ```shell
   forge build
   ```

5. Run the tests:
   ```shell
   forge test
   ```

Feel free to explore the code and dive into the exercises provided to enhance your understanding of Compound Finance. Happy practicing!

## Script setup

1. Create `.env` in the root directory:

2. Add the following to the `.env` file:

```shell
SEPOLIA_RPC_URL=https://rpc.sepolia.org
ETHERSCAN_API_KEY=YOUR_API_KEY
PRIVATE_KEY=YOUR_PRIVATE_KEY
```

3. Run the depoly script:

```shell
forge script script/Compound.s.sol:CompoundScript --broadcast --verify --rpc-url sepolia
```
