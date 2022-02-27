import org.web3j.crypto.Hash;
import org.web3j.protocol.core.methods.response.EthBlock;
import org.web3j.protocol.core.methods.response.Transaction;

import java.io.File;
import java.io.FileWriter;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.List;

public class Keccak256OfTransactionReceiver implements DataCollector {

    private final FileWriter fileWriter;
    private static final int MODULUS = 256;
    private int count = 0;

    public Keccak256OfTransactionReceiver() throws IOException {
        File file = this.createNewFile();
        this.fileWriter = new FileWriter(file);
    }

    @Override
    public void collectData(EthBlock block) throws IOException {
        List<EthBlock.TransactionResult> transactionsResult = block.getBlock().getTransactions();
        byte[] receiverBytes;
        if (!transactionsResult.isEmpty()) {
            Object firstTransaction =  block.getBlock().getTransactions().get(0);
            Transaction transaction = ((EthBlock.TransactionObject) firstTransaction).get();
            String receiver = transaction.getTo();
            if (receiver != null) {
                receiverBytes = receiver.getBytes(StandardCharsets.UTF_8);
            } else {
                receiverBytes = new byte[0];
            }
        } else {
            receiverBytes = new byte[0];
        }
        byte[] bytes = Hash.sha3(receiverBytes);
        int generatedValue = convertByteArrayToInteger(bytes);
        generatedValue = generatedValue % MODULUS;
        fileWriter.write(generatedValue + "\n");
        if (++count % 1000 == 0) {
            fileWriter.flush();
        }
    }

    @Override
    public void endCollection() throws IOException {
        this.fileWriter.write("entries: " + count + "\n");
        this.fileWriter.flush();
        this.fileWriter.close();
    }

    @Override
    public String collectorName() {
        return "keccak-256-of-transaction-receiver";
    }
}
