import org.web3j.protocol.Web3j;
import org.web3j.protocol.core.DefaultBlockParameter;
import org.web3j.protocol.core.methods.response.EthBlock;
import org.web3j.protocol.core.methods.response.EthBlockNumber;
import org.web3j.protocol.core.methods.response.Web3ClientVersion;
import org.web3j.protocol.http.HttpService;

import java.io.IOException;
import java.math.BigInteger;

public class DataCollectorManager {

    private static final BigInteger AMOUNT_OF_DATA_TO_COLLECT = new BigInteger("100000");
    private static DataCollector[] COLLECTOR = new DataCollector[0];
    private static BigInteger startFromBlock = null;
    private static Integer collectedSoFar = 0;

    static {
        try {
            COLLECTOR = new DataCollector[]{new Keccak256OfBlockHash(), new Keccak256OfTimestamp(), new Keccak256OfTransactionReceiver(), new Keccak256OfTransactionValue()};
        } catch (IOException e) {
            System.out.println("Não possível criar os coletores");
        }
    }

    public static void main(String[] args) {
        try {
            // Inicia conexão
            System.out.println("Connecting to Ethereum ...");
            Web3j web3 = Web3j.build(new HttpService("https://cloudflare-eth.com"));
            System.out.println("Successfuly connected to Ethereum");
            System.out.println("Startint at: " + System.currentTimeMillis());
            // eth_blockNumber returns the number of most recent block.
            Web3ClientVersion clientVersion = web3.web3ClientVersion().send();
            // Escolhe o início da coleta aleatoriamente
            if (startFromBlock == null) {
                EthBlockNumber lastBlockNumber = web3.ethBlockNumber().send();
                startFromBlock = lastBlockNumber.getBlockNumber().subtract(AMOUNT_OF_DATA_TO_COLLECT);
                collectedSoFar = 0;
            }
            BigInteger iterator = startFromBlock;
            for (int i = collectedSoFar; i < AMOUNT_OF_DATA_TO_COLLECT.intValue(); i++) {
                try {
                    EthBlock block = web3.ethGetBlockByNumber(DefaultBlockParameter.valueOf(iterator), true).send();
                    for (DataCollector dataCollector : COLLECTOR) {
                        dataCollector.collectData(block);
                    }
                    iterator = iterator.add(BigInteger.ONE);
                    System.out.println("Coletado com sucesso " + iterator + "(" + (i+1) + ")");
                } catch (IOException e) {
                    System.out.println("Erro ao coletar bloco " + iterator + "(" + (i+1) + ")");
                }
            }
            for (DataCollector dataCollector : COLLECTOR) {
                try {
                    dataCollector.endCollection();
                } catch (IOException e) {
                    System.out.println("Não foi possível terminar a coleta de " + dataCollector.collectorName());
                }
            }
            // Print result
            System.out.println("---------Fim de Coleta---------");
            System.out.println("Client version: " + clientVersion.getWeb3ClientVersion());
            System.out.println("Block number: " + startFromBlock);
            System.out.println("Lista de coletores:");
            for (DataCollector dataCollector : COLLECTOR) {
                System.out.println("\t" + dataCollector.collectorName());
            }
        } catch (IOException ex) {
            throw new RuntimeException("Error whilst sending json-rpc requests", ex);
        }
    }
}
