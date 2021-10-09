async function main() {
	const [deployer] = await ethers.getSigners();
	const balance = await deployer.getBalance();
	console.log(`\nAccount balance: ${balance}\n`);
	const listContract = await deployList();

	const equityAddress = await deployEquity(listContract.address, 
		["0x0000000000000000000000000000000000000000"])
	await listContract.setEquityContract(equityAddress);

}

main().then(() => process.exit(0))
	.catch(error => {
		console.log(error);
		process.exit(1);
})

async function deployList() {
	console.log("Deploying List contract...");
	const ListContract = await ethers.getContractFactory('List');
	const listContract = await ListContract.deploy();

	console.log(`List contract deployed at: ${listContract.address}`);
	return listContract;
}
async function deployEquity(listContract, currencies) {	
	console.log("Deploying Equity contract...");
	const EquityContract = await ethers.getContractFactory('Equity');
	const equityContract = await EquityContract.deploy(listContract, 
		currencies);
	console.log(`Equity contract deployed at: ${equityContract.address}`);
	return equityContract.address;
}