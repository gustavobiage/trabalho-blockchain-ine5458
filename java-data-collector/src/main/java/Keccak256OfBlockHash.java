import org.bouncycastle.util.encoders.Hex;
import org.web3j.crypto.Hash;
import org.web3j.protocol.core.methods.response.EthBlock;

import java.io.File;
import java.io.FileWriter;
import java.io.IOException;

public class Keccak256OfBlockHash implements DataCollector {

    private final FileWriter fileWriter;
    private static final int MODULUS = 256;
    private int count = 0;

    public Keccak256OfBlockHash() throws IOException {
        File file = this.createNewFile();
        this.fileWriter = new FileWriter(file);
    }

    @Override
    public void collectData(EthBlock block) throws IOException {
        String hash = block.getBlock().getHash();
        String resultString = Hash.sha3(hash);
        byte[] bytes = Hex.decode(resultString.substring(2));
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
        return "keccak-256-of-block-hash";
    }
}
