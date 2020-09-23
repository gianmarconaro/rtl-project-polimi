----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 08.03.2020 15:56:41
-- Design Name: 
-- Module Name: final_project - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_UNSIGNED.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity project_reti_logiche is
    Port (
        i_clk       : in std_logic;                           -- segnale di clock
        i_start     : in std_logic;                         -- segnale di start
        i_rst       : in std_logic;                           -- segnale di reset della macchina
        i_data      : in std_logic_vector(7 downto 0);       -- segnale che arriva dalla memoria dopo la richiesta
        o_address   : out std_logic_vector(15 downto 0);  -- segnale che manda l'indirizzo in memoria
        o_done      : out std_logic;                         -- segnale che comunica la fine
        o_en        : out std_logic;                           -- segnale di enable per poter comunicare con la memoria
        o_we        : out std_logic;                           -- segnale di write enable per poter scrivere nella memoria
        o_data      : out std_logic_vector (7 downto 0)      -- segnale di uscita verso la memoria
        );
end project_reti_logiche;

architecture FSM of project_reti_logiche is
    type state_type is (A, B, C, D, E, F, G, H);
    type wz_array is array (0 to 8) of std_logic_vector(6 downto 0);  
    signal index : integer := 0;  
    signal a1 : wz_array;
    signal current_state : state_type := A;
    signal mem : std_logic_vector(15 downto 0) := "0000000000000000";

begin
    state_reg : process(i_clk, i_rst)
    
    variable insert_in_mem : std_logic_vector(7 downto 0);
    variable wz_offset : std_logic_vector(3 downto 0);
    variable wz_bit : std_logic;
    variable wz_num : std_logic_vector(2 downto 0);
    
    begin
        if i_rst = '1' then -- sono nello stato iniziale e resetto i segnali
            -- stato di reset
            o_en <= '0';
            o_we <= '0';
            o_done <= '0';
            o_address <= "0000000000000000";
            mem <= "0000000000000000";
            wz_offset := "0000";
            index <= 0;
            current_state <= A;
        elsif rising_edge(i_clk) then
            case current_state is
            -- nello stato A leggo gli indirizzi dalla memoria
            when A =>
                o_en <= '1'; -- attivo il segnale di interazione con la memoria
                o_we <= '0'; -- disattivo segnale di scrittura in memoria
                o_done <= '0';
                o_address <= mem; -- prendo l'indirizzo che sta in mem
                -- Sto leggendo le wz e il dato in input
                if mem <= 7 then 
                    o_en <= '1';
                    current_state <= B;
                elsif mem = 8 and i_start = '1' then
                    o_en <= '1';
                    current_state <= B;
                -- Ho letto il dato in input
                else
                    -- Segnale i_start basso --> aspetto
                    if i_start = '0' then
                        o_en <= '0';
                    -- Segnale i_start alto --> procedo
                    elsif i_start = '1' then
                        o_en <= '1';
                        current_state <= D;
                    end if;      
                end if;
            -- nello stato B aspetto che venga caricato o_address in i_data
            when B =>
                o_en <= '1'; -- attivo il segnale di interazione con la memoria
                o_we <= '0'; -- disattivo segnale di scrittura in memoria
                o_done <= '0';
                current_state <= C;
            -- nello stato C salvo gli indirizzi precedenti nell vettore a1
            when C =>
                o_en <= '1';
                o_we <= '0';
                o_done <= '0';
                if index = 8 and i_start = '1' then
                    a1(8) <= i_data(6 downto 0);
                elsif index <= 7 then
                    a1(index) <= i_data(6 downto 0);
                    index <= index + 1;
                end if;
                mem <= mem + 1;
                current_state <= A;
            -- nello stato D vedo se l'indirizzo appartiene alla wz o meno
            when D => 
                o_en <= '0'; -- disattivo il segnale di interazione con la memoria
                o_we <= '0'; -- disattivo il segnale di scrittura in memoria
                o_done <= '0';
                for i in 0 to 7 loop
                    for j in 0 to 3 loop
                        if a1(i) + j = a1(8) then    
                            wz_num := std_logic_vector(to_unsigned(i, 3));                
                            if j = 0 then
                                wz_offset := "0001";
                            elsif j = 1 then 
                                wz_offset := "0010";
                            elsif j = 2 then
                                wz_offset := "0100";
                            elsif j = 3 then 
                                wz_offset := "1000";
                            end if;
                        end if;
                    end loop;
                end loop;
                -- stabilisco se l'addr sta nella wz o no
                if wz_offset = "0000" then -- addr non sta nella wz
                    wz_bit := '0';
                    current_state <= E;
                else
                    wz_bit := '1';
                    current_state <= E;
                end if;
            -- nello stato E compongo il dato da inserire in memoria
            when E =>
                o_en <= '0'; -- disattivo il segnale di interazione con la memoria
                o_we <= '0'; -- disattivo il segnale di scrittura in memoria
                o_done <= '0';
                if wz_bit = '0' then -- addr non si trova all'interno di nessuna wz
                    insert_in_mem := wz_bit & a1(8);
                    current_state <= F;
                elsif wz_bit = '1' then -- addr si trova in una wz
                    insert_in_mem := wz_bit & wz_num & wz_offset;
                    current_state <= F;
                end if;
            -- nello stato F inserisco il dato in memoria
            when F =>
                o_en <= '1';
                o_we <= '1';
                o_done <= '0';
                o_data <= insert_in_mem;
                o_address <= "0000000000001001";
                current_state <= G;
            -- nello stato G aspetto che il dato venga inserito in memoria e attivo il segnale di done
            when G =>
                o_en <= '1';
                o_we <= '1';
                o_done <= '0';
                current_state <= H;
            -- il dato è stato inserito in memoria, quindi sistemo i segnali
            when H =>
                o_en <= '0';
                o_we <= '0';
                if i_start = '1' then
                    o_done <= '1'; -- ho finito
                end if;
                if i_start = '0' then
                    o_done <= '0';
                    mem <= "0000000000001000";
                    wz_offset := "0000";
                    index <= 8;
                    current_state <= A;
                end if;
            end case;
        end if;
    end process;
end FSM;