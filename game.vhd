
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
-- use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity project2 is
    Port ( clk : in  STD_LOGIC;
           sw0 : in  STD_LOGIC;
           sw1 : in  STD_LOGIC;
           sw2 : in  STD_LOGIC;
           sw3 : in  STD_LOGIC;
           Hsync : out  STD_LOGIC;
           Vsync : out  STD_LOGIC;
			  horizcounter : out integer;
			  vertcounter	: out integer;
           DAC_CLK : out  STD_LOGIC;
           rout : out  STD_LOGIC_VECTOR (7 downto 0);
           gout : out  STD_LOGIC_VECTOR (7 downto 0);
           bout : out  STD_LOGIC_VECTOR (7 downto 0));
end project2;

architecture Behavioral of project2 is

	----------------------
	-- VGA Known Parameters
	----------------------
	constant h_front_porch : integer := 16; --padding after new line in active display is being drawn
	constant h_complete_line : integer := 800;--num of pixels/clock cycles in a compelete horizontal line.
	constant h_sync_pulse : integer := 96; -- hsync pulse duration
	constant v_front_porch : integer := 10; -- padding after drawing active display in vertical direction
	constant v_complete_frame : integer := 525;--num of pixel/clock cycles in a complete vertical line
	constant v_sync_pulse : integer := 2; -- vsync pulse duration, resets to new frame at the top of screen
	-----------------------------
	-- Clock Generation Signals
	-----------------------------
	signal clk_div : STD_LOGIC := '0'; -- slowed down clock
	signal clk_counter : integer := 0; -- clock counter
	signal clk_motion : STD_LOGIC := '0'; 
	--------------------------
	-- Pixel display signals
	--------------------------
	signal is_video_on : STD_LOGIC; --for determining if drawing in active display
	signal h_counter : integer := 0;
	signal v_counter : integer := 0;
	signal p1_x : integer := 50;
	signal p1_y : integer := 360;
	signal p2_x : integer := 580;
	signal p2_y : integer := 60;
	signal ball_x : integer := 310;
	signal ball_y : integer := 230; -- center = (360, 240)
	signal h_dir : STD_LOGIC; -- 0 = right, 1 = left
	signal v_dir : STD_LOGIC; -- 0 = down,  1  = up
	
	begin

	----------------------------
	-- Clock Divider
	----------------------------
	process (clk)
	begin
		-- slow down clock because drawing a pixel takes longer than internal clock frequency 
		--need to slow down clock so the pixels are drawn on the VGA at the correct rate to avoid distortion
		if (clk'Event and clk = '1') then
			clk_div <= NOT clk_div;
			if (clk_counter  = 100000) then -- start the game over. back to clk_counter =0 
				clk_motion <= NOT clk_motion;
				clk_counter <= 0;
			else
				clk_counter <= clk_counter + 1; --increase the clock counter
			end if;
		end if;
	end process;

	------------------------
	-- Pixel Configuration
	------------------------
	-- sw3 resets the game
	process (clk_div)
	begin
			if (clk_div'Event and clk_div = '1') then
				-------------------------------------------
				-- Counter for pixel location calculation
				-------------------------------------------
				--keep a track of the pixel positions on screen
				-- check if H counter is 800 clock cycles - 640 pixels + padding
				if (h_counter < h_complete_line - 1) then
					-- if not going to new line, increase the counter one clock cycle at a time		
					h_counter <= h_counter + 1;
				else
					h_counter <= 0;--end of a horizontal line so reset the counter
				-- check if full full frame has been drawn (525 lines)
				if (v_counter < v_complete_frame - 1) then
					v_counter <= v_counter + 1; 
				else
					v_counter <= 0; -- end of a vertical line, go to next frame
				end if;
				end if;
				-----------------------------------------
				-- Sync configuration
				-----------------------------------------
				-- Horizontal Sync
				--checks if current pixel is within the active region or front porch
				if ((h_counter < 639 + h_front_porch) OR (h_counter >= 639 + h_front_porch + h_sync_pulse)) then -- check if pixel is within the active 
					Hsync <= '1'; -- still not done the line
				else
					Hsync <= '0';-- h_counter is the sync pulse region indicating ready for new line
				end if;
				-- Vertical Sync
				if ((v_counter < 479 + v_front_porch) OR (v_counter >= 479 + v_front_porch + v_sync_pulse)) then
					Vsync <= '1'; -- still not done the frame
				else
					Vsync <= '0';-- start of a new frame
				end if;
				------------------------------------------
				-- Determine pixel avilability
				------------------------------------------
				--is the current position within the visible screen
				if ((h_counter < 640) AND (v_counter < 480)) then
					is_video_on <= '1'; --the pixel is in the visible area of the active region
				else
					is_video_on <= '0';--the pixel is not in the visible area of the active region
				end if;
			end if;
		--end if;
	end process;
	------------------
	-- Motion Update
	------------------
	process (clk_motion, sw0, sw2, p1_y, p2_y)
	begin
		if (clk_motion'Event and clk_motion = '1') then
			-----------------------------
			-- Update Player 1 location
			-----------------------------
			if (sw0 = '1') then
				if (sw1 = '0') then -- vertical position of player 1 
					if (p1_y < 360) then -- bottom boundary - clamped to stay within the playable field 
						p1_y <= p1_y + 1; -- 0 = down and 1 = moves up
					else
						p1_y <= 360;
					end if;
				else
					if (p1_y > 40) then -- top boundary - clamped to stay within the playable field
						p1_y <= p1_y - 1;
					else
						p1_y <= 40; -- 0 = down, 1 = up
					end if;
				end if;
			end if;
			-----------------------------
			-- Update Player 2 location
			-----------------------------
			if (sw2 = '1') then  
				if (sw3 = '0') then -- same logic as player 1
					if (p2_y < 360) then
						p2_y <= p2_y + 1;
					else
						p2_y <= 360;
					end if;
				else
					if (p2_y > 40) then
						p2_y <= p2_y - 1;
					else
						p2_y <= 40;
					end if;
				end if;
			else
				p2_y <= p2_y;
			end if;
			------------------------------
			-- Update direction
			------------------------------
			--player1's horizontal position
			if ( ball_x >= p1_x and ball_x < p1_x + 10) then --checks if ballx coord falls with player 1 paddle right edge, if true ball is alighned with paddle
				if ( ((ball_y >= p1_y) or (ball_y + 10 >= p1_y)) and ((ball_y < p1_y + 80) or (ball_y + 10 < p1_y + 80)) ) then --if balls vertical range overlaps with vertical range of player 1s paddle. Makes sure top and bottom are alighned as well
					h_dir <= '0';--bounces back to the right
				end if;
			elsif ( ball_x = 40 ) then --checks if balls left edge has reach left boundary 
				if ( (ball_y >= 40 and ball_y < 160) or (ball_y + 10 >= 360 and ball_y + 10 < 440) ) then --checks if vertical position overlaps with specific gates near boundary (look at the ranges)
					h_dir <= '0';--bounces to the right
				end if;
				
			elsif (ball_x + 10 > p2_x and ball_x + 10 <= p2_x + 10) then --has it moved past the left edge of player 2s paddle
				if ( ((ball_y >= p2_y) or (ball_y + 10 >= p2_y)) and ((ball_y < p2_y + 80) or (ball_y + 10 < p2_y + 80)) ) then --is ball within the width of the paddle
					h_dir <= '1';--if both are true that means the ball is horizontally aligned with players 2 paddle --- ball bounces to the left
				end if;
			elsif (ball_x + 10 = 600) then --checks if the right edge of ball has reached the right boundary - 600
				if ( (ball_y >= 40 and ball_y < 160) or (ball_y + 10 >= 360 and ball_y + 10 < 440) ) then -- same as before make sure its in the gate range - check if vertical position overlaps with speific gates near the right boundary
					h_dir <= '1';--balls horizontal direction changes to move left
				end if;
			end if;
			if ( ball_y - 1 <= 40 ) then--top boundary - making sure ball doesnt hit the top boundary or border
				v_dir <= '1'; --down
			elsif (ball_y + 11 >= 440) then--bottom boundary -making sure ball doesnt hit the bottom boundary or border
				v_dir <= '0';--up
			end if;
			-----------------------------
			-- Update ball location
			-----------------------------
			if ((ball_x > 0) and (ball_x + 10) < 639) then -- make sure ball is within the horizontal bounds of the screen
				-- Horizontal - if true continue and updated the positons
				if (h_dir = '0') then--right - based on the horizontal direction of ball in x direction
					ball_x <= ball_x + 1; -- increment by one to move the ball on pixel to right
				elsif (h_dir = '1') then--left -- decrement ball x by one to move ball 1 pixel to the left
					ball_x <= ball_x - 1;
				end if;
				-- Vertical
				if (v_dir = '0') then --up - decrease bally by 1 to move ball 1 pixel up
					ball_y <= ball_y - 1;
				elsif(v_dir = '1') then --down - increase bally by 1 to move ball 1 pixel down
					ball_y <= ball_y + 1;
				end if; 
			else
				ball_x <= 300; --reset to the centre
				ball_y <= 220;
			end if;
		end if;
	end process;
	-------------------------------- 
	-- Pixel Color Set
	--------------------------------
	process (is_video_on)
	begin
		if (is_video_on = '0') then
			Rout <= (others => '0');
			Gout <= (others => '0');
			Bout <= (others => '0');
		else
			if (h_counter >= 20 and h_counter < 640 - 20 and v_counter >=20 and v_counter < 460) then
				if ( v_counter < 40 or v_counter >= 440) then
					rout <= (others => '1');  -- Display white for top & bottom border
					gout <= (others => '1');
					bout <= (others => '1');
				elsif (((h_counter < 40) OR (h_counter >= 640 - 40)) and (v_counter < 160 or v_counter >= 320)) then
					rout <= (others => '1');  -- Display white for left & right border
					gout <= (others => '1');
					bout <= (others => '1');
				elsif ((h_counter >= ball_x and h_counter < ball_x + 10) and (v_counter >= ball_y and v_counter < ball_y + 10) )then
					rout <= (others => '1');   -- Color Ball inside play field (gate + border)
					gout <= (others => '1');
					bout <= (others => '0');
				elsif ((h_counter >= p1_x and h_counter < p1_x + 10) and (v_counter >= p1_y and v_counter < p1_y + 80) )then
					rout <= (others => '0');   -- Color Player 1
					gout <= (others => '0');
					bout <= (others => '1');
				elsif ((h_counter >= p2_x and h_counter < p2_x + 10) and (v_counter >= p2_y and v_counter < p2_y + 80) )then
					rout <= (others => '1');   -- Color Player 2
					gout <= (others => '0');
					bout <= (others => '1');
				elsif ((v_counter >= 40 and v_counter < 440 and h_counter > 320 and h_counter <= 325)) and (((v_counter - 35) mod 64) > 32) then
					rout <= (others => '0');   -- Color center line
					gout <= (others => '0');
					bout <= (others => '0');
				else
					rout <= (others => '0');	-- Color background
					gout <= (others => '1');
					bout <= (others => '0');
				end if;
			elsif ((h_counter >= ball_x and h_counter < ball_x + 10) and (v_counter >= ball_y and v_counter < ball_y + 10) )then
				rout <= (others => '1');   -- Color Ball when it scores
				gout <= (others => '0');
				bout <= (others => '0');
			else
				rout <= (others => '0');	-- Color background
				gout <= (others => '1');
				bout <= (others => '0');
			end if;
		end if;
	end process;
	
	DAC_CLK <= clk_div;
	horizcounter <= h_counter;
	vertcounter <= v_counter;

end Behavioral;