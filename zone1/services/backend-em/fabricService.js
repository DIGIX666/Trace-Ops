const grpc = require('@grpc/grpc-js');
const { connect, signers } = require('@hyperledger/fabric-gateway');
const fs = require('fs').promises;
const path = require('path');
const crypto = require('crypto');

// --- CONFIGURATION ---
const MSP_ID = 'OrgEMMSP';
const CHANNEL_NAME = 'traceops';
const CHAINCODE_NAME = 'decision';

async function getPrivateKey(keystorePath) {
    const files = await fs.readdir(keystorePath);
    const keyFile = files.find(file => file.endsWith('_sk'));
    if (!keyFile) throw new Error(`Aucun fichier _sk dans ${keystorePath}`);

    const keyPath = path.join(keystorePath, keyFile);
    let keyBuffer = await fs.readFile(keyPath);
    
    // Nettoyage : conversion en string pour enlever d'éventuels caractères invisibles (\r)
    const keyString = keyBuffer.toString().trim();

    try {
        return crypto.createPrivateKey(keyString);
    } catch (err) {
        console.log(keyString)
        console.log("Error getting private key: ", err)
    }
}

async function createGatewayConnection() {
    console.log("1 - Chargement du JSON");
    const ccpPath = path.resolve(__dirname, 'zone1-write-connection.json');
    const ccp = JSON.parse(await fs.readFile(ccpPath, 'utf8'));

    const peerName = 'peer0.orgem.traceops.local';
    const peerURL = ccp.peers[peerName].url.replace('grpcs://', '');
    console.log(peerURL)
    const tlsCert = Buffer.from(ccp.peers[peerName].tlsCACerts.pem);

    const client = new grpc.Client(
        peerURL, 
        grpc.credentials.createSsl(tlsCert), 
        {
            'grpc.ssl_target_name_override': 'peer0.orgem.traceops.local', // Force le nom attendu
        }
    );

    console.log("2 - Lecture du certificat");
    const certPath = path.resolve(__dirname, 'wallet/cert.pem');
    const credentials = await fs.readFile(certPath);

    console.log("3 - Recherche de la clé privée...");
    const keystorePath = path.resolve(__dirname, 'wallet/');
    
    const privateKey = await getPrivateKey(keystorePath); 
    console.log("4 - Clé privée chargée avec succès");

    const gateway = connect({
        client,
        identity: { mspId: MSP_ID, credentials }, // Utilise la variable credentials lue plus haut
        signer: signers.newPrivateKeySigner(privateKey),
        evaluateOptions: () => ({ deadline: Date.now() + 5000 }),
        endorseOptions: () => ({ deadline: Date.now() + 5000 }),
    });
    
    console.log("5 - Gateway connectée");
    return { gateway, client };
}

// --- FONCTIONS CRUD ---

/**
 * Écriture : Appelle SubmitDecision
 * @param {string} decisionID - Unique ID
 * @param {object} payload - Données JSON
 * @param {string} appHash - Hash SHA256 calculé côté application
 */
async function submitDecision(decisionID, payload, appHash) {
    const { gateway, client } = await createGatewayConnection();
    try {
        const network = gateway.getNetwork(CHANNEL_NAME);
        const contract = network.getContract(CHAINCODE_NAME);

        console.log(`\n--> Submit Transaction: SubmitDecision, ID: ${decisionID}`);

        // On transforme l'objet payload en string JSON pour le Go
        const payloadString = JSON.stringify(payload);

        // submitTransaction envoie la donnée à l'orderer et attend le bloc
        await contract.submitTransaction('SubmitDecision', decisionID, payloadString, appHash);
        
        console.log('*** Transaction committed successfully');
        return { success: true };
    } catch(err) {
        console.log("Error submiting decision : ", err)
    } finally {
        gateway.close();
        client.close();
    }
}

/**
 * Lecture : Appelle QueryDecision
 */
async function queryDecision(decisionID) {
    const { gateway, client } = await createGatewayConnection();
    try {
        const network = gateway.getNetwork(CHANNEL_NAME);
        const contract = network.getContract(CHAINCODE_NAME);

        console.log(`\n--> Evaluate Transaction: QueryDecision, ID: ${decisionID}`);

        const resultBytes = await contract.evaluateTransaction('QueryDecision', decisionID);
        const resultString = new TextDecoder().decode(resultBytes);
        
        return JSON.parse(resultString);
    } finally {
        gateway.close();
        client.close();
    }
}

module.exports = { submitDecision, queryDecision };