import java.awt.image.BufferedImage;
import javax.imageio.ImageIO;
import java.io.File;
import java.io.IOException;

public class ImageToBinary {
  public static void main(String[] args) {
    // Read the image file
    BufferedImage image = null;
    try {
      image = ImageIO.read(new File("C:/Users/Alfre50/Pictures/Pixelart/REX/3dmm_rex8.png"));
    } catch (IOException e) {
      System.out.println("Error reading image file");
      System.exit(1);
    }

    // Get image dimensions
    int width = image.getWidth();
    int height = image.getHeight();
    System.out.println(".DB "+height+","+width);

    int countLine = 0;

    // Iterate over all pixels
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        int color = image.getRGB(x, y);
        int red = (color >> 16) & 0xff;
        int green = (color >> 8) & 0xff;
        int blue = color & 0xff;
        // If the pixel is not white (255, 255, 255), set it to 0
        // Otherwise, set it to 1
        int binary = (red == 255 && green == 255 && blue == 255) ? 0 : 1;

        if(countLine==0) System.out.print(".DB %");
        else if(countLine%8 == 0) System.out.print(",%");
        System.out.print(binary);
        countLine++;
      }
      //Add padding to unfinished final bytes (happens if image width isn't divisible by 8)
      if (countLine%8 != 0){
        for(;countLine%8 != 0;countLine++) System.out.print("0");
      }
      countLine = 0;
      System.out.println();
    }
  }
}
