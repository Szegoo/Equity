async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying Equity contract with " + deployer.address);

  const balance = await deployer.getBalance();
  console.log(`Account balance: ${balance}`);

  const EquityContract = await ethers.getContractFactory('Equity');
  const equityContract = await EquityContract.deploy(deployer.address, 
    "0x0000000000000000000000000000000000000000");
  
  console.log(`Equity contract deployed at: ${equityContract.address}`);
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.log(error);
    process.exit(1);
  })
