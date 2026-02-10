require('dotenv').config();

const grpc = require('@grpc/grpc-js');
const { connect, signers } = require('@hyperledger/fabric-gateway');
const fs = require('fs').promises;
const path = require('path');
const crypto = require('crypto');

// --- CONFIGURATION ---
const MSP_ID = process.env.FABRIC_MSP_ID;
const CHANNEL_NAME = process.env.FABRIC_CHANNEL_NAME;
const CHAINCODE_NAME = process.env.FABRIC_CHAINCODE_NAME;

// --- FONCTION UTILITAIRE MODIFIÉE ---
async function getPrivateKeyPath(keystorePath) {
    const files = await fs.readdir(keystorePath);
    const keyFile = files.find(file => file.endsWith('_sk'));
    if (!keyFile) throw new Error(`Aucun fichier _sk dans ${keystorePath}`);
    return path.join(keystorePath, keyFile);
}

async function createGatewayConnection() {
    console.log("Hello:", process.env.FABRIC_CCP_PATH)
    const ccpPath = path.resolve(__dirname, process.env.FABRIC_CCP_PATH);
    const ccp = JSON.parse(await fs.readFile(ccpPath, 'utf8'));

    const peerName = process.env.FABRIC_PEER_NAME;
    let peerURL = ccp.peers[peerName].url.replace('grpcs://', '');
    
    // Correction Docker (comme tu as fait)
    peerURL = peerURL.replace('localhost', 'peer0.orgem.traceops.local');
    peerURL = peerURL.replace('127.0.0.1', 'peer0.orgem.traceops.local');
    
    const tlsCert = Buffer.from(ccp.peers[peerName].tlsCACerts.pem);

    const certPath = path.resolve(__dirname, process.env.FABRIC_CERT_PATH);
    const credentials = await fs.readFile(certPath); // Buffer du certificat client

    const keystorePath = path.resolve(__dirname, process.env.FABRIC_WALLET_PATH);
    const keyPath = await getPrivateKeyPath(keystorePath);
    const privateKeyBuffer = await fs.readFile(keyPath); // Buffer de la clé (pour mTLS)
    
    // Création de l'objet KeyObject pour le Signer Fabric
    const privateKeySigner = crypto.createPrivateKey(privateKeyBuffer.toString());

    // --- C'EST ICI QUE TOUT SE JOUE (mTLS) ---
    const client = new grpc.Client(
        peerURL,
        grpc.credentials.createSsl(
            tlsCert,           // 1. Certificat racine du serveur (CA)
            privateKeyBuffer,  // 2. Clé privée du client (mTLS) <--- AJOUT IMPORTANT
            credentials        // 3. Certificat du client (mTLS) <--- AJOUT IMPORTANT
        ),
        {
            'grpc.ssl_target_name_override': 'peer0.orgem.traceops.local',
            'grpc.default_authority': 'peer0.orgem.traceops.local' // Parfois nécessaire
        }
    );

    const gateway = connect({
        client,
        identity: { mspId: MSP_ID, credentials }, 
        signer: signers.newPrivateKeySigner(privateKeySigner), // On utilise l'objet crypto ici
        evaluateOptions: () => ({ deadline: Date.now() + 5000 }),
        endorseOptions: () => ({ deadline: Date.now() + 5000 }),
    });
    
    return { gateway, client };
}

// --- FONCTIONS CRUD ---

async function pullAllData() {
    const { gateway, client } = await createGatewayConnection();
    try {
        const network = gateway.getNetwork(CHANNEL_NAME);
        const contract = network.getContract(CHAINCODE_NAME);

        console.log(`\nGetAllDecisions --> Récupération de tout le registre`);

        // On utilise evaluateTransaction car c'est une opération en lecture seule
        const resultBytes = await contract.evaluateTransaction("GetAllDecisions");
        
        const resultString = new TextDecoder().decode(resultBytes);
        if (!resultString) return [];
        
        return JSON.parse(resultString);
    } catch(err) {
        console.error("Error pulling all data : ", err);
        throw err;
    } finally {
        gateway.close();
        client.close();
    }
}

module.exports = { pullAllData };
