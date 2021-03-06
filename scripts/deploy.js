async function main() {
	const [deployer] = await ethers.getSigners();
	const balance = await deployer.getBalance();
	console.log(`\nAccount balance: ${balance}\n`);
	const listContract = await deployList();

	const equityAddress = await deployEquity(listContract.address, 
		["0x0000000000000000000000000000000000000000"])
	await listContract.setEquityContract(equityAddress);
	await sendLink(listContract.address);
}

main().then(() => process.exit(0))
	.catch(error => {
		console.log(error);
		process.exit(1);
})

async function deployList() {
	console.log("Deploying List contract...");
	const ListContract = await ethers.getContractFactory('List');
	//timeToWait is defined in seconds
	const listContract = await ListContract.deploy(120);

	console.log(`List contract deployed at: ${listContract.address}`);
	return listContract;
}
async function deployEquity(listContract, currencies) {	
	console.log("Deploying Equity contract...");
	const EquityContract = await ethers.getContractFactory('Equity');
	const equityContract = await EquityContract.deploy(listContract, 
		currencies, 120);
	console.log(`Equity contract deployed at: ${equityContract.address}`);
	return equityContract.address;
}
async function sendLink(listAddr) {
	console.log(`sending link to List Contract(${listAddr})`);
	const LinkToken = await ethers.getContractFactory("LinkToken");

	//setting the address of the link token deployed on the kovan testnet
	const linkToken = await LinkToken.attach(
		"0xa36085F69e2889c224210F603D836748e7dC0088"
	)
	await linkToken.transfer(listAddr, Math.pow(10, 18).toString());
}