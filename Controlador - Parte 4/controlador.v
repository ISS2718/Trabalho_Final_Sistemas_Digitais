//Controlador de um conversor AD

//Beatriz Cardoso de Oliveira - 12566400
//Fernando Lucas Vieira Souza - 12703069
//Isaac Santos Soares - 12751713
//Joao Pedro Gonçalves Ferreira - 12731314
//Nicholas Estevao Pereira de Oliveira Rodrigues Bragança - 12689616
//Pedro Antonio Bruno Grando - 12547166

module tff(output reg q, qb, input clk, clrn, t);
	//Flip-flop do tipo T
	always @ (negedge clk or negedge clrn)
		if (~clrn)
			q = 1'b0;
		else
			q = t ^ q;
    assign qb = ~q;
endmodule

module counter10 (cnt_en, q, clk, rstn, enb, q_ant);
  	//Contador de Década (0 a 9)
	output [3:0] q; //Saída: Valor da contagem em BCD com 4 bits
  	output reg cnt_en; //Saída: Sinal de enable do próximo contador
  
  	input clk, rstn, enb; //Entrada: clock e reset síncrono, sinal de enable do contador atual
	input [3:0] q_ant; //Entrada: Sinal com o valor atual do contador anterior
  	
  	//Contador de décadas tradicional:
    wire [3:0] tv;
  	assign tv = {((q[3] & q[0])|(q[0] & q[1] & q[2]))& enb, (q[1] & q[0])& enb, (q[0] & ~q[3])& enb, (1'b1)& enb};
	
    genvar i;
    generate
       for (i=0; i<4; i=i+1)
         tff u0 (.q(q[i]), .qb(), .clk(clk), .clrn(rstn), .t(tv[i]));
    endgenerate
  	
  	//Controle do próximo contador: (sinal de enable)
  	always @(posedge clk) begin
      if(q == 4'b1001 && q_ant == 4'b1001) // Se a contagem do contador atual 
        //e do contador anterior valem 9 => ativa o próximo contador
      	cnt_en = 1'b1;
      else
        cnt_en = 1'b0; // Caso contrário, não ativa o próximo contador
  	end

endmodule

module counter999BCD (q1, q2, q3, clk, rstn);
  output [3:0] q1, q2, q3;//Saída: Valores BCD da contagem
  input clk, rstn; //Entrada: Sinal de clock e reset
   
  reg [2:0] cnt_en; // Sinais de enable dos contadores
  
  counter10 u0 (.q(q1), .cnt_en(cnt_en[0]), .clk(clk), .rstn(rstn), .enb(clk), .q_ant(4'b1001)); //Contador de Unidade
  counter10 d0 (.q(q2), .cnt_en(cnt_en[1]), .clk(clk), .rstn(rstn), .enb(cnt_en[0]), .q_ant(q1));//Contador de Dezena
  counter10 c0 (.q(q3), .cnt_en(cnt_en[2]), .clk(clk), .rstn(rstn), .enb(cnt_en[1]), .q_ant(q2));//Contador de Centena
  // Todos controlados pelos mesmo clock com reset síncrono
  
endmodule

module controlador (inicio, clk, ch_vm, ch_ref, ch_zr, rst_s, Vint_z,desc_u,desc_d,desc_c);
  	input inicio, clk, Vint_z, rst_s; //Entradas: sinal de inicio, clock, tensão no integrador (respectivamente), sinal de reset do contador
  	output reg ch_vm, ch_ref, ch_zr; //Saídas: Sinais das chaves e sinal "rst_s"
  	output reg [3:0] desc_u,desc_d,desc_c; //Saídas: tempo de descida medido (unidade, dezena e centena) (funcionam como registradores)
 	reg enb_3; //Sinal de enable (identifica quando a contagem chega em 999) (determina mudança de estado)
  	reg [3:0] cont_u,cont_d,cont_c; //Unidade, dezena e centena da contagem do contador999
  	reg cnt_rst = 1'b0;// Sinal de reset do contador999 (obs: conta se o reset vale 1)
  
  counter999BCD u0 (.q1(cont_u), .q2(cont_d), .q3(cont_c), .clk(clk), .rstn(cnt_rst || rst_s)); //Definição do contador999 que será usado nas medições de tempo
  
  	//Definição do sinal de enable (enb_3)  
  	always @(posedge clk) begin
      if(cont_u == 4'b1001 && cont_d == 4'b1001 && cont_c == 4'b1001) // Se a contagem vale 999:
      		enb_3 = 1'b1;
   	 	else // Caso contrário:
      		enb_3 = 1'b0;
 	end
  
  	//Definição dos estados:
  	localparam CARREGAR=2'b01, DESCARREGAR=2'b10, ZERAR=2'b11;
  	reg [1:0] state, nextState;
  	
  	//Definição do estado inicial e mudança de estado:
  	always @(posedge clk) begin
    	if(inicio == 1'b1)
          	state <= ZERAR; //Estado padrão (quando inicio vale 1)
  		else begin
    		state <= nextState;
   	 	end
  	end
  
  	//Definição das transições de estados:
  	always @(*) begin
    	nextState = state; 
    	case (state)
      	CARREGAR: begin
        	ch_vm = 1'b1; // Liga a chave vm
        	ch_ref = 1'b0;
        	ch_zr = 1'b0;
        	cnt_rst = 1'b1;
          if(enb_3 == 1'b1) begin //Contagem chegou em 999 => fim do tempo tm
          		cnt_rst = 1'b0; //para de contar
          		nextState = DESCARREGAR;
        	end else
        		nextState = CARREGAR; //Se não chegou em 999 continua contando
      	end
      	DESCARREGAR: begin
        	ch_vm = 1'b0;
       		ch_ref = 1'b1;// Liga a chave ref
        	ch_zr = 1'b0;
          	//Aguarda a tensão de saída no integrador ser 0 (Vint_z = 1)
          if(Vint_z == 1'b1) begin 
         		desc_u = cont_u; //Registra a contagem atual
          		desc_d = cont_d;
          		desc_c = cont_c;
          		nextState = ZERAR; 
        	end else
        		nextState = DESCARREGAR; // Continua aguardando Vint_z = 1
      	end
      	ZERAR: begin 
          	//Aguarda a saída do integrador ser 0 (Vint_z = 1)
          cnt_rst = 1'b0;// Reseta a contagem
          if(Vint_z == 1'b1)            	
        		nextState = CARREGAR;
        	else begin //Se a saída do integrador não vale 0 => continua aguardando
				ch_vm = 1'b0;
       			ch_ref = 1'b0;
       			ch_zr = 1'b1; // Liga a chave zr
        		nextState = ZERAR;
        	end
      	end
    	default: begin
     		nextState = ZERAR; // Estado padrão
    	end
    	endcase
  	end
  
endmodule
