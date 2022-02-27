import org.web3j.crypto.Hash;
import org.web3j.protocol.core.methods.response.EthBlock;
import org.web3j.protocol.core.methods.response.Transaction;

import java.io.File;
import java.io.FileWriter;
import java.io.IOException;
import java.math.BigInteger;

public class Keccak256OfTransactionValue implements DataCollector {

    private final FileWriter fileWriter;
    private static final int MODULUS = 256;
    private int count = 0;

    public Keccak256OfTransactionValue() throws IOException {
        File file = this.createNewFile();
        this.fileWriter = new FileWriter(file);
    }

    @Override
    public void collectData(EthBlock block) throws IOException {
        Transaction transaction = null;
        for (Object nonZeroValuetransaction : block.getBlock().getTransactions()) {
            Transaction t = ((EthBlock.TransactionObject) nonZeroValuetransaction).get();
            if (t.getValue().compareTo(BigInteger.ZERO) != 0) {
                transaction = t;
            }
        }

        BigInteger value;
        if (transaction != null) {
            value = transaction.getValue();
        } else {
            value = BigInteger.ZERO;
        }
        byte[] bytes = Hash.sha3(value.toByteArray());
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
        return "keccak-256-of-transaction-value";
    }
}