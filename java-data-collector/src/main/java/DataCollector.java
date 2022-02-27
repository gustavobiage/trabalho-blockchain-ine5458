import org.web3j.protocol.core.methods.response.EthBlock;

import java.io.File;
import java.io.IOException;
import java.nio.ByteBuffer;
import java.util.Arrays;
import java.util.Random;

public interface DataCollector {

    /**
     * Gera um id aleatório da execução
     * @return valor aleatório
     */
    default String generateRandomId() {
        Random random = new Random();
        int id = random.nextInt(10000);
        return String.format("%04d", id);
    }

    default File createNewFile() throws IOException {
        // Encontra um nome de arquivo que ainda não existe
        String filename = "data-collected-" + this.collectorName() + "-" + generateRandomId() + ".txt";
        File file = new File("src/main/resources/" + filename);
        while (file.exists()) {
            filename = "data-collected-" + this.collectorName() + "-" + generateRandomId() + ".txt";
            file = new File("src/main/resources/" + filename);
        }
        if (file.createNewFile()) {
            return file;
        }
        return null;
    }

    default int convertByteArrayToInteger(byte[] bytes) {
        byte[] unsigned = new byte[bytes.length + 1];
        unsigned[0] = 0;
        System.arraycopy(bytes, 0, unsigned, 1, bytes.length);
        ByteBuffer buffer = ByteBuffer.wrap(unsigned);
        return buffer.getInt();
    }

    /**
     * Gera um valor aleatório a partir de uma entropia.
     */
    void collectData(EthBlock block) throws IOException;

    /**
     * Termina a geração de valores aleatórios.
     */
    void endCollection() throws IOException;

    /**
     * Retorna o nome do coletor
     * @return nome do coletor
     */
    String collectorName();
}
