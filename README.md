# TI84_3DMM
**3D Monster Maze** (1982) port for **TI-84 Plus** calculators (Z80 ASM)
This port includes the option to render the game using **ray-casting**, 
apart from the **original** method for rendering the **3D view**.

```
██████╗ ██████╗
╚════██╗██╔══██╗
 █████╔╝██║  ██║
 ╚═══██╗██║  ██║
██████╔╝██████╔╝
╚═════╝ ╚═════╝
███╗   ███╗ ██████╗ ███╗   ██╗███████╗████████╗███████╗██████╗ 
████╗ ████║██╔═══██╗████╗  ██║██╔════╝╚══██╔══╝██╔════╝██╔══██╗
██╔████╔██║██║   ██║██╔██╗ ██║███████╗   ██║   █████╗  ██████╔╝
██║╚██╔╝██║██║   ██║██║╚██╗██║╚════██║   ██║   ██╔══╝  ██╔══██╗
██║ ╚═╝ ██║╚██████╔╝██║ ╚████║███████║   ██║   ███████╗██║  ██║
╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═══╝╚══════╝   ╚═╝   ╚══════╝╚═╝  ╚═╝
███╗   ███╗ █████╗ ███████╗███████╗
████╗ ████║██╔══██╗╚══███╔╝██╔════╝
██╔████╔██║███████║  ███╔╝ █████╗  
██║╚██╔╝██║██╔══██║ ███╔╝  ██╔══╝  
██║ ╚═╝ ██║██║  ██║███████╗███████╗
╚═╝     ╚═╝╚═╝  ╚═╝╚══════╝╚══════╝
```
(c) Original game by Malcolm Evans, published by J.K. Greye Software Ltd. and New Generation Software

Conversion by **Alfredo Rodríguez Sanfrutos**.
	For my Bachelor's Degree Final Project, Computer Engineering @ Universidad Politécnica de Madrid.
	Tutor: Juan Zamorano Flores

## FAQ
### How to execute it in a real TI-84 Plus or TI-84 Plus Silver Edition?
Install and open TI Connect(r), select 'Send To TI Device'. Select your device.
Now, select the program.8xk file or drag it to the 'Send To TI Device' window.
Then, click 'Send to Device'.
When it's done transferring the file, open the APPS menu on your calculator, select 3DMM and press Enter.
In the first screen, you will be prompted to select the rendering system. Select (MODE) ORIGINAL for the standard game,
or (DEL) RAYCASTED for the extra ray-casting rendering.

### Why do this in Assembly?
I wanted to explore the world of 3D environments and games from the ground up, so I had to start in Assembly, of course.
There was a Texas Instruments TI-84 Plus I got for 5€ laying around, so I started investigating and ended up with this!
