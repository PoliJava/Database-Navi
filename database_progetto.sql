--
-- PostgreSQL database dump
--

-- Dumped from database version 15.5
-- Dumped by pg_dump version 15.5

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: after_insert_prenotazione(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.after_insert_prenotazione() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
declare
	data_pass date;
	rand_numb integer;
	nome_pass passeggero.nome%type;
	cognome_pass passeggero.cognome%type;
	result_string varchar(100);
	age_pass integer;
	disponibilita_corsa integer;
	data_corsa cadenzagiornaliera.datainizio%type;
	tempo_year integer;
	tempo_month integer;
	tempo_day integer;
begin
	
	select disponibilita into disponibilita_corsa 
	from corsa 
	where idcorsa = new.idcorsa;
	
	-- se la disponibilita della corsa è uguale a zero, non è possibile effettuare la prenotazione e viene lanciata un'eccezione
	if disponibilita_corsa = 0 then
	
		raise exception 'I posti per questa corsa sono esauriti.';
		
	else
	
		select nome, cognome, datanascita into nome_pass, cognome_pass, data_pass 
		from passeggero 
		where idpasseggero = new.idpasseggero;
		
		-- nella variabile data_corsa viene memorizzata la data di inizio della cadenza giornaliera corrispondente
		-- alla corsa specifica della prenotazione. Viene utilizzata per calcolare il sovrapprezzo della prenotazione
		select datainizio into data_corsa 
		from cadenzagiornaliera
		where nomecadenzagiornaliera in (select nomecadenzagiornaliera 
										 from corsa
										 where idcorsa = new.idcorsa);
		
		-- la funzione concat concatena una stringa ad un'altra separata da uno spazio
		result_string := concat(nome_pass, ' ', cognome_pass);
		
		-- viene utilizzata la funzione random per generare un codice biglietto in maniera casuale. 
		-- la funzione floor viene utilizzata per indicare che i numeri devono essere interi
		rand_numb := floor(random() * 1000000) :: integer + 1;
		
		-- queste istruzioni servono a calcolare la differenza tra una data ed un'altra.
		-- viene utilizzata la funzione extract per estrarre l'anno, il mese o il giorno da una data
		-- e successivamente la funzione age calcola la differenza (e quindi l'eta) tra i due valori.
		select extract(year from age(current_date, data_pass)) into age_pass;
		
		select extract(year from age(data_corsa, current_date)) into tempo_year;
		select extract(month from age(data_corsa, current_date)) into tempo_month;
		select extract(day from age(data_corsa, current_date)) into tempo_day;

		-- se l'eta è minore di 18 anni, verrà effettuato un inserimento in bigliettoridotto e acquistoridotto
		if(age_pass < 18) then
		
			-- se la prenotazione viene effettuata prima della data di inizio del periodo in cui si attiva una corsa,
			-- allora viene aggiunto un sovrapprezzo alla prenotazione
			if (tempo_year > 0 or tempo_month > 0 or tempo_day > 0) then
				insert into bigliettoridotto values (rand_numb, 10.50 + new.sovrapprezzoprenotazione + new.sovrapprezzobagagli, result_string);
				insert into acquistoridotto values (rand_numb, new.idpasseggero);
			
			-- se la prenotazine invece viene effettuata durante il periodo in cui la corsa è attiva,
			-- allora non ci sarà nessun sovrapprezzo da aggiungere al prezzo totale
			else 
				insert into bigliettoridotto values (rand_numb, 10.50 + new.sovrapprezzobagagli, result_string);
				insert into acquistoridotto values (rand_numb, new.idpasseggero);
				
			end if;
		-- l'eta è maggiore di 18 quindi l'inserimento viene effettuato in bigliettointero e acquistointero
		else 
			
			-- lo stesso ragionamento viene utilizzato per il calcolo in bigliettointero
			if (tempo_year > 0 or tempo_month > 0 or tempo_day > 0) then
				insert into bigliettointero values (rand_numb, 15.50 + new.sovrapprezzoprenotazione + new.sovrapprezzobagagli, result_string);
				insert into acquistointero values (rand_numb, new.idpasseggero);
				
			else 
			
				insert into bigliettointero values (rand_numb, 15.50 + new.sovrapprezzobagagli, result_string);
				insert into acquistointero values (rand_numb, new.idpasseggero);
				
			end if;
			
		end if;
	
	end if;
		
	return new;
	
	
end;
$$;


ALTER FUNCTION public.after_insert_prenotazione() OWNER TO postgres;

--
-- Name: FUNCTION after_insert_prenotazione(); Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON FUNCTION public.after_insert_prenotazione() IS '-- funzione che, dopo l''inserimento di una tupla in prenotazione, attiva il trigger che permette di aggiungere una tupla corrispondente in bigliettoridotto e in acquistoridotto se l''età è minore di 18, oppure in bigliettointero e acquistointero se l''età è maggiore di 18. Questa funzione inoltre permette di indicare l''eventuale sovrapprezzo della prenotazione o il sovrapprezzo dei bagagli, e di diminuire la disponibilità nella tabella corsa';


--
-- Name: aggiungi_navigazione(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.aggiungi_navigazione() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
declare
	cod_natante varchar(15);
begin
	
	-- Seleziona un natante per la stessa compagnia di navigazione della corsa appena inserita
    SELECT codnatante INTO cod_natante
    FROM natante
    WHERE nomecompagnia = NEW.nomecompagnia
    ORDER BY random() -- Seleziona casualmente un natante della stessa compagnia
    LIMIT 1;
	
	IF cod_natante is not null THEN
		INSERT INTO navigazione VALUES (NEW.idcorsa, cod_natante);
	ELSE
		RAISE EXCEPTION 'Nessun natante trovato per la compagnia di cui si vuole inserire la corsa';
	END IF;
	
    RETURN NEW;
	
end;
$$;


ALTER FUNCTION public.aggiungi_navigazione() OWNER TO postgres;

--
-- Name: diminuisci_disponibilita(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.diminuisci_disponibilita() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
	
	update corsa
	set disponibilita = disponibilita - 1
	where idcorsa = new.idcorsa;
	
	return new;
	
end;
$$;


ALTER FUNCTION public.diminuisci_disponibilita() OWNER TO postgres;

--
-- Name: elimina_prenotazione(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.elimina_prenotazione() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
declare
	cod_bigl_r bigliettoridotto.codbigliettor%type;
	cod_bigl_i bigliettointero.codbigliettoi%type;
	data_pass date;
	age_pass integer;
begin
		
	select codbigliettor into cod_bigl_r from acquistoridotto where idpasseggero = old.idpasseggero;
	select codbigliettoi into cod_bigl_i from acquistointero where idpasseggero = old.idpasseggero;
	select datanascita into data_pass from passeggero where idpasseggero = old.idpasseggero;

	-- calcola l'età del passeggero
	select extract(year from age(current_date, data_pass)) into age_pass;
	
	--se l'eta è minore di 18, allora le tuple vengono eliminate in acquistoridotto e bigliettoridotto
	if(age_pass < 18) then
	
		delete from acquistoridotto where idpasseggero = old.idpasseggero;
		delete from bigliettoridotto where codbigliettor = cod_bigl_r;

	-- l'età è maggiore di 18 quindi le tuple vengono eliminate da acquistointero e bigliettointero
	else 
	
		delete from acquistointero where idpasseggero = old.idpasseggero;
		delete from bigliettointero where codbigliettoi = cod_bigl_i;
		
	end if;
	
	-- aggiornamento della disponibilita dopo la cancellazione di una prenotazione
	update corsa
	set disponibilita = disponibilita + 1
	where idcorsa = old.idcorsa;
	
	return new;
end;
$$;


ALTER FUNCTION public.elimina_prenotazione() OWNER TO postgres;

--
-- Name: imposta_disponibilita(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.imposta_disponibilita() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
declare
	capienzap INTEGER; --capienza passeggeri
	capienzaa INTEGER; --capienza automezzi
	tipo_natante varchar(50); --tipo del natante
begin
	
	-- Seleziona la capienza passeggeri e il tipo del natante associato alla corsa
	select capienzapasseggeri, tiponatante into capienzap, tipo_natante
	from natante
	where codnatante in (select codnatante
						from navigazione
						where idcorsa = new.idcorsa);
	
	-- Seleziona la capienza passeggeri del natante associato alla corsa
	select capienzaautomezzi into capienzaa
	from natante
	where codnatante in (select codnatante
						from navigazione
						where idcorsa = new.idcorsa);
	
	-- Verifica il tipo del natante e imposta la disponibilità della corsa di conseguenza
	if tipo_natante = 'traghetto' then
	
        -- Se il natante è un traghetto, la disponibilità è data dalla somma della capienza passeggeri e automezzi
		update corsa 
		set disponibilita = capienzap + capienzaa
		where idcorsa = new.idcorsa;
		
	else
	
        -- Altrimenti, la disponibilità è data solo dalla capienza passeggeri
		update corsa
		set disponibilita = capienzap
		where idcorsa = new.idcorsa;
		
	end if;
		
	return new;
end;
$$;


ALTER FUNCTION public.imposta_disponibilita() OWNER TO postgres;

--
-- Name: incrementa_id_passeggero(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.incrementa_id_passeggero() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
 
begin

	new.idpasseggero = nextval('sequenza_id_passeggero'); --funzione che restituisce il prossimo elemento nella sequenza
	return new;
	
end;
$$;


ALTER FUNCTION public.incrementa_id_passeggero() OWNER TO postgres;

--
-- Name: incrementa_numero_natanti(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.incrementa_numero_natanti() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
	
	update compagniadinavigazione
	set numeronatanti = numeronatanti + 1
	where nomecompagnia = new.nomecompagnia;
	
	return new;
end;
$$;


ALTER FUNCTION public.incrementa_numero_natanti() OWNER TO postgres;

--
-- Name: modifica_ritardo(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.modifica_ritardo() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN

    
    IF NEW.ritardo IS DISTINCT FROM OLD.ritardo THEN 
	-- condizione aggiunta per evitare che il ciclo prosegua all'infinito, 
	-- verificando se il nuovo ritardo è diverso dal vecchio ritardo

        IF NEW.ritardo IS NOT NULL AND NEW.ritardo != 'canc' THEN 
		-- Se il nuovo ritardo non è nullo o 'canc' (indica che la corsa è stata cancellata), aggiorna la tabella corsa con il nuovo ritardo
		
            UPDATE corsa
            SET ritardo = NEW.ritardo
            WHERE idcorsa = NEW.idcorsa;
			
        ELSE
            -- Altrimenti, imposta il ritardo a 'canc' nella tabella corsa
			
            UPDATE corsa
            SET ritardo = 'canc' 
            WHERE idcorsa = NEW.idcorsa;
			
			UPDATE corsa
			SET disponibilita = 0
			WHERE idcorsa = NEW.idcorsa;
			
        END IF;
		
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION public.modifica_ritardo() OWNER TO postgres;

--
-- Name: prezzo_bagaglio(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.prezzo_bagaglio() RETURNS trigger
    LANGUAGE plpgsql
    AS $$

begin
	
	if new.peso_bagaglio <= 5 then
		new.sovrapprezzobagagli = 0.0;
	elsif new.peso_bagaglio > 5 and new.peso_bagaglio <= 50 then
		new.sovrapprezzobagagli = 10.0;
	elsif new.peso_bagaglio > 50 then
		new.sovrapprezzobagagli = 15.0;
	end if;
	
	return new;
	
end;
$$;


ALTER FUNCTION public.prezzo_bagaglio() OWNER TO postgres;

--
-- Name: random_between(integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.random_between(low integer, high integer) RETURNS integer
    LANGUAGE plpgsql STRICT
    AS $$
BEGIN
   RETURN floor(random()* (high-low + 1) + low);
END;
$$;


ALTER FUNCTION public.random_between(low integer, high integer) OWNER TO postgres;

--
-- Name: setta_sovrapprezzoprenotazione(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.setta_sovrapprezzoprenotazione() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
declare
	data_corsa date;
	tempo_year integer;
	tempo_month integer;
	tempo_day integer;
begin

	select datainizio into data_corsa 
	from cadenzagiornaliera
	where nomecadenzagiornaliera in (select nomecadenzagiornaliera 
									 from corsa
									 where idcorsa = new.idcorsa);
									
	select extract(year from age(data_corsa, current_date)) into tempo_year;
	select extract(month from age(data_corsa, current_date)) into tempo_month;
	select extract(day from age(data_corsa, current_date)) into tempo_day;
	
	-- se la prenotazione viene effettuata durante il periodo in cui si attiva la corsa, allora il sovrapprezzo è settato a 3
	if (tempo_year > 0 or tempo_month > 0 or tempo_day > 0) then
	
		new.sovrapprezzoprenotazione = 3.00;
		
	else
	--altrimenti a 0
	
		new.sovrapprezzoprenotazione = 0;
		
	end if;
	
	return new;
end;
$$;


ALTER FUNCTION public.setta_sovrapprezzoprenotazione() OWNER TO postgres;

--
-- Name: verifica_disponibilita_auto(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.verifica_disponibilita_auto() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
declare
	tipo natante.tiponatante%type;
begin
	select tiponatante into tipo
	from natante
	where codnatante in (select codnatante 
						from navigazione 
						where idcorsa = new.idcorsa);
						
	if tipo = 'traghetto' and new.auto = true then
		update prenotazione
		set auto = true
		where idcorsa = new.idcorsa;
		
		update corsa
		set disponibilita = disponibilita - 1
		where idcorsa = new.idcorsa;
	else
		raise exception 'Impossibile aggiungere l''auto, perchè l''imbarcazione non lo permette';
	end if;
	
	return new;
end;
$$;


ALTER FUNCTION public.verifica_disponibilita_auto() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: acquistointero; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.acquistointero (
    codbigliettoi integer NOT NULL,
    idpasseggero integer NOT NULL
);


ALTER TABLE public.acquistointero OWNER TO postgres;

--
-- Name: acquistoridotto; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.acquistoridotto (
    codbigliettor integer NOT NULL,
    idpasseggero integer NOT NULL
);


ALTER TABLE public.acquistoridotto OWNER TO postgres;

--
-- Name: bigliettointero; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.bigliettointero (
    codbigliettoi integer NOT NULL,
    prezzo double precision DEFAULT 15.50,
    nominativo character varying(100) NOT NULL
);


ALTER TABLE public.bigliettointero OWNER TO postgres;

--
-- Name: bigliettoridotto; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.bigliettoridotto (
    codbigliettor integer NOT NULL,
    prezzo double precision DEFAULT 10.50,
    nominativo character varying(100) NOT NULL
);


ALTER TABLE public.bigliettoridotto OWNER TO postgres;

--
-- Name: cadenzagiornaliera; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.cadenzagiornaliera (
    datainizio date NOT NULL,
    datafine date NOT NULL,
    giornosettimanale character varying(70) NOT NULL,
    orariopartenza time without time zone NOT NULL,
    orarioarrivo time without time zone NOT NULL,
    nomecadenzagiornaliera character varying(100) NOT NULL,
    CONSTRAINT ck_date CHECK ((datainizio < datafine))
);


ALTER TABLE public.cadenzagiornaliera OWNER TO postgres;

--
-- Name: compagniadinavigazione; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.compagniadinavigazione (
    nomecompagnia character varying(50) NOT NULL,
    numeronatanti integer DEFAULT 0,
    telefono character varying(15),
    mail character varying(50),
    sitoweb character varying(50)
);


ALTER TABLE public.compagniadinavigazione OWNER TO postgres;

--
-- Name: corsa; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.corsa (
    idcorsa character varying(15) NOT NULL,
    nomecompagnia character varying(30),
    cittapartenza character varying(30) NOT NULL,
    cittaarrivo character varying(30) NOT NULL,
    scalo character varying(30),
    ritardo character varying(4),
    disponibilita integer,
    nomecadenzagiornaliera character varying(100)
);


ALTER TABLE public.corsa OWNER TO postgres;

--
-- Name: indirizzosocial; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.indirizzosocial (
    indirizzo character varying(50) NOT NULL,
    nomecompagnia character varying(50)
);


ALTER TABLE public.indirizzosocial OWNER TO postgres;

--
-- Name: natante; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.natante (
    codnatante character varying(15) NOT NULL,
    nomecompagnia character varying(30),
    tiponatante character varying(30),
    capienzapasseggeri integer,
    capienzaautomezzi integer,
    CONSTRAINT ck_capienzapasseggeri CHECK ((capienzapasseggeri > 0)),
    CONSTRAINT ck_tiponatante CHECK (((tiponatante)::text = ANY ((ARRAY['traghetto'::character varying, 'aliscafo'::character varying, 'motonave'::character varying, 'altro'::character varying])::text[])))
);


ALTER TABLE public.natante OWNER TO postgres;

--
-- Name: navigazione; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.navigazione (
    idcorsa character varying(15) NOT NULL,
    codnatante character varying(15) NOT NULL
);


ALTER TABLE public.navigazione OWNER TO postgres;

--
-- Name: passeggero; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.passeggero (
    idpasseggero integer NOT NULL,
    nome character varying(50) NOT NULL,
    cognome character varying(50) NOT NULL,
    datanascita date NOT NULL
);


ALTER TABLE public.passeggero OWNER TO postgres;

--
-- Name: prenotazione; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.prenotazione (
    idcorsa character varying(15) NOT NULL,
    idpasseggero integer NOT NULL,
    sovrapprezzoprenotazione double precision DEFAULT 3.00,
    sovrapprezzobagagli double precision,
    idprenotazione integer NOT NULL,
    peso_bagaglio double precision,
    auto boolean
);


ALTER TABLE public.prenotazione OWNER TO postgres;

--
-- Name: prenotazione_idprenotazione_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.prenotazione_idprenotazione_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.prenotazione_idprenotazione_seq OWNER TO postgres;

--
-- Name: prenotazione_idprenotazione_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.prenotazione_idprenotazione_seq OWNED BY public.prenotazione.idprenotazione;


--
-- Name: sequenza_id_passeggero; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.sequenza_id_passeggero
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.sequenza_id_passeggero OWNER TO postgres;

--
-- Name: prenotazione idprenotazione; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.prenotazione ALTER COLUMN idprenotazione SET DEFAULT nextval('public.prenotazione_idprenotazione_seq'::regclass);


--
-- Data for Name: acquistointero; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.acquistointero (codbigliettoi, idpasseggero) FROM stdin;
758384	32
551993	100
64560	98
762030	101
315867	31
659041	40
454198	75
400726	76
588434	74
512929	74
200614	74
747784	74
661269	122
36776	121
683437	118
223367	74
808772	74
454098	6
95859	6
861462	6
908366	3
96955	3
567109	4
584068	3
949961	10
672019	22
409290	88
853673	56
306620	122
520067	45
331388	78
504754	15
480524	102
151219	33
211108	70
96418	95
626713	12
514151	55
996519	90
139941	110
525418	6
296068	30
539731	75
360058	40
967542	85
370165	115
901140	25
961790	68
628953	50
236377	55
405705	52
781011	61
927302	66
\.


--
-- Data for Name: acquistoridotto; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.acquistoridotto (codbigliettor, idpasseggero) FROM stdin;
4462	60
900883	60
911210	65
926044	69
163845	57
661230	58
933997	63
\.


--
-- Data for Name: bigliettointero; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.bigliettointero (codbigliettoi, prezzo, nominativo) FROM stdin;
758384	28.5	Michele Leone
551993	15.5	Antonio Barbieri
64560	30.5	Roberto Longo
762030	25.5	Laura Farina
315867	15.5	Laura Costa
659041	25.5	Vincenzo Marini
454198	18.5	Porfirio Tramontana
400726	18.5	Lorenzo Morelli
588434	28.5	Eliana Illiano
512929	28.5	Eliana Illiano
200614	28.5	Eliana Illiano
747784	28.5	Eliana Illiano
661269	18.5	Marta Battaglia
36776	33.5	Andrea Palmieri
683437	28.5	Claudia Guerrieri
223367	25.5	Eliana Illiano
808772	25.5	Eliana Illiano
454098	28.5	Silvio Barra
95859	28.5	Silvio Barra
861462	25.5	Silvio Barra
908366	15.5	Antonio Lamore
96955	15.5	Antonio Lamore
567109	15.5	Simone Iavarone
584068	28.5	Antonio Lamore
949961	28.5	Luca Ferrari
672019	28.5	Giovanni Esposito
409290	25.5	Gianluca De Angelis
853673	28.5	Luca Ferrari
306620	15.5	Marta Battaglia
520067	28.5	Valeria Ferri
331388	28.5	Luigi Ferraro
504754	25.5	Martina Gallo
480524	25.5	Nicola Ferri
151219	28.5	Alessandra Barbieri
211108	28.5	Enrico Pellegrini
96418	28.5	Martina Serra
626713	25.5	Paolo Moretti
514151	25.5	Martina Bianchi
996519	25.5	Simone Esposito
139941	28.5	Riccardo Mariani
525418	28.5	Silvio Barra
296068	28.5	Christian Villa
539731	28.5	Porfirio Tramontana
360058	25.5	Vincenzo Marini
967542	28.5	Valentina Lombardi
370165	25.5	Giulia Caprioli
901140	25.5	Anna Rinaldi
961790	28.5	Giovanni Esposito
628953	28.5	Alessio Costantini
236377	28.5	Martina Bianchi
405705	28.5	Daniele Palmieri
781011	25.5	Giulia Gallo
927302	28.5	Antonio De Angelis
\.


--
-- Data for Name: bigliettoridotto; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.bigliettoridotto (codbigliettor, prezzo, nominativo) FROM stdin;
4462	23.5	Andrea Conti
900883	23.5	Andrea Conti
911210	20.5	Simona Rizzo
926044	23.5	Valentina Caruso
163845	20.5	Alessia Romano
661230	23.5	Paolo Moretti
933997	13.5	Eleonora Lombardi
\.


--
-- Data for Name: cadenzagiornaliera; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.cadenzagiornaliera (datainizio, datafine, giornosettimanale, orariopartenza, orarioarrivo, nomecadenzagiornaliera) FROM stdin;
2024-02-01	2024-04-30	lunedi - mercoledi	10:00:00	11:00:00	napoli-ischia primavera2024
2023-12-15	2024-02-29	sabato - domenica	09:30:00	12:00:00	salerno-cagliari weekend inverno 2024
2024-05-15	2024-09-15	tutti i giorni	10:30:00	11:30:00	corsa estiva 2024 pozzuoli-procida-ischia
2024-09-20	2024-12-07	lunedi, martedi, mercoledi, giovedi, venerdi	07:00:00	15:00:00	civitavecchia-olbia infrasettimanale autunno 2024
2024-03-21	2024-05-21	lunedi, mercoledi, venerdi	13:20:00	15:00:00	genova-napoli lun-mer-ven primavera 2024
2024-06-01	2024-09-30	martedi, giovedi, sabato, domenica	09:00:00	10:50:00	ischia-ponza estate 2024
2024-06-01	2024-09-30	martedi, giovedi, sabato, domenica	09:00:00	10:50:00	ponza-ischia estate 2024
2024-06-01	2024-09-30	martedi, sabato, domenica	09:00:00	10:50:00	ventotene-napoli estate 2024
2024-06-01	2024-09-30	martedi, sabato, domenica	15:00:00	16:50:00	napoli-ventotene estate 2024
2024-06-01	2024-09-30	martedi, sabato, domenica	10:00:00	16:50:00	napoli-panarea estate 2024
2024-06-01	2024-09-30	martedi, sabato, domenica	15:00:00	21:50:00	panarea-napoli estate 2024
2024-06-01	2024-09-30	sabato, domenica	10:00:00	13:30:00	capri-castellammare primavera/estate 2024
2024-06-01	2024-09-30	sabato, domenica	10:00:00	13:30:00	castellammare-capri primavera/estate 2024
2024-01-31	2024-09-30	lunedi, mercoledi, giovedi, sabato, domenica	10:00:00	10:50:00	napoli-capri febbraio-settembre 2024
2024-01-31	2024-09-30	lunedi, mercoledi, giovedi, sabato, domenica	10:00:00	10:50:00	capri-napoli febbraio-settembre 2024
2023-12-15	2024-02-29	lunedi	10:00:00	12:50:00	cagliari-salerno bisettimanale inverno 2024
2023-11-15	2024-01-31	lunedi	10:00:00	12:50:00	livorno-olbia lunedi inverno 2024
2023-11-15	2024-01-31	lunedi	10:00:00	12:50:00	olbia-livorno lunedi inverno 2024
\.


--
-- Data for Name: compagniadinavigazione; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.compagniadinavigazione (nomecompagnia, numeronatanti, telefono, mail, sitoweb) FROM stdin;
NaviExpress	3	\N	\N	\N
NavItalia	4	0123456789	navitalia@compagnia.com	navitalia.it
OndAnomala	5	999888777666	ondanomala@compagnia.com	ondAnomala.it
MareChiaroT	1	000111222333	marechiarot@compagnia.com	marechiarot.com
\.


--
-- Data for Name: corsa; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.corsa (idcorsa, nomecompagnia, cittapartenza, cittaarrivo, scalo, ritardo, disponibilita, nomecadenzagiornaliera) FROM stdin;
10	OndAnomala	CIVITAVECCHIA	OLBIA	\N	\N	69	civitavecchia-olbia infrasettimanale autunno 2024
12	OndAnomala	PONZA	ISCHIA	\N	\N	149	ponza-ischia estate 2024
14	MareChiaroT	PANAREA	NAPOLI	\N	\N	149	panarea-napoli estate 2024
11	OndAnomala	ISCHIA	PONZA	\N	\N	68	ischia-ponza estate 2024
19	OndAnomala	LIVORNO	OLBIA	\N	\N	144	livorno-olbia lunedi inverno 2024
17	NaviExpress	CAGLIARI	SALERNO	\N	\N	48	cagliari-salerno bisettimanale inverno 2024
16	MareChiaroT	VENTOTENE	NAPOLI	\N	\N	148	ventotene-napoli estate 2024
1	NavItalia	CAPRI	CASTELLAMMARE	NAPOLI	\N	48	capri-castellammare primavera/estate 2024
2	OndAnomala	NAPOLI	ISCHIA	\N	10'	148	napoli-ischia primavera2024
4	NaviExpress	SALERNO	CAGLIARI	\N	\N	146	salerno-cagliari weekend inverno 2024
15	MareChiaroT	NAPOLI	VENTOTENE	\N	\N	147	napoli-ventotene estate 2024
7	NavItalia	CASTELLAMMARE	CAPRI	NAPOLI	\N	22	castellammare-capri primavera/estate 2024
9	NavItalia	NAPOLI	CAPRI	\N	\N	48	napoli-capri febbraio-settembre 2024
18	OndAnomala	OLBIA	LIVORNO	\N	30'	56	olbia-livorno lunedi inverno 2024
3	NavItalia	POZZUOLI	ISCHIA	PROCIDA	\N	23	corsa estiva 2024 pozzuoli-procida-ischia
5	NaviExpress	CIVITAVECCHIA	OLBIA	\N	\N	47	civitavecchia-olbia infrasettimanale autunno 2024
13	MareChiaroT	NAPOLI	PANAREA	\N	\N	145	napoli-panarea estate 2024
6	NaviExpress	GENOVA	NAPOLI	\N	canc	0	genova-napoli lun-mer-ven primavera 2024
8	NavItalia	CAPRI	NAPOLI	\N	\N	194	capri-napoli febbraio-settembre 2024
\.


--
-- Data for Name: indirizzosocial; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.indirizzosocial (indirizzo, nomecompagnia) FROM stdin;
@navi_Italia_official	NavItalia
Navi Italia	NavItalia
@OndAnomala_	OndAnomala
@Mare_Chiaro_Traghetti	MareChiaroT
\.


--
-- Data for Name: natante; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.natante (codnatante, nomecompagnia, tiponatante, capienzapasseggeri, capienzaautomezzi) FROM stdin;
1	NaviExpress	aliscafo	50	0
5	NaviExpress	aliscafo	50	0
7	NaviExpress	traghetto	100	50
2	OndAnomala	traghetto	100	50
3	NavItalia	motonave	25	0
4	NavItalia	aliscafo	50	0
6	NavItalia	traghetto	150	50
8	NavItalia	traghetto	150	50
9	OndAnomala	traghetto	100	50
10	OndAnomala	aliscafo	75	0
11	OndAnomala	aliscafo	60	0
12	OndAnomala	motonave	60	0
13	MareChiaroT	traghetto	100	50
\.


--
-- Data for Name: navigazione; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.navigazione (idcorsa, codnatante) FROM stdin;
2	2
3	3
4	7
5	5
6	7
1	4
7	3
8	6
9	4
10	10
11	10
12	2
13	13
14	13
15	13
16	13
17	1
18	11
19	2
1	5
\.


--
-- Data for Name: passeggero; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.passeggero (idpasseggero, nome, cognome, datanascita) FROM stdin;
8	Marco	Rossi	1992-06-15
9	Giulia	Bianchi	1988-09-23
10	Luca	Ferrari	1975-02-10
11	Alessia	Romano	1996-03-28
12	Paolo	Moretti	1981-08-04
13	Francesca	Ricci	1994-11-17
14	Andrea	Conti	1978-12-22
15	Martina	Gallo	1985-05-08
16	Davide	Mancini	1990-01-20
17	Eleonora	Lombardi	1976-07-04
18	Riccardo	Martini	1998-09-17
19	Simona	Rizzo	1983-03-22
20	Antonio	De Angelis	1993-10-05
21	Sofia	De Santis	1979-06-14
22	Giovanni	Esposito	1986-12-31
23	Valentina	Caruso	1997-06-27
24	Enrico	Pellegrini	1984-03-13
25	Anna	Rinaldi	1996-09-09
26	Fabio	Caputo	1981-04-26
27	Silvia	Serra	1998-02-11
28	Matteo	Galli	1979-10-17
29	Elena	Piras	1999-07-23
30	Christian	Villa	1986-05-02
31	Laura	Costa	1992-11-29
32	Michele	Leone	1977-07-07
33	Alessandra	Barbieri	1993-04-15
34	Stefano	Farina	1988-12-08
35	Beatrice	Sanna	1995-01-01
36	Gabriele	Migliore	1984-09-24
37	Linda	Marchetti	1997-06-12
38	Massimo	Bruno	1977-11-22
39	Federica	Longo	1993-08-30
40	Vincenzo	Marini	1988-04-06
41	Serena	Mariani	1994-01-14
42	Claudio	Russo	1981-06-18
43	Elisa	Poli	1997-02-25
44	Gabriel	D'Amico	1986-10-12
45	Valeria	Ferri	1992-07-01
46	Tommaso	Caprioli	1979-03-09
47	Ilaria	Pizzuti	1995-11-26
48	Guido	Bellini	1980-02-19
49	Miriam	Guerrieri	1994-10-04
50	Alessio	Costantini	1989-03-28
51	Sara	Coppola	1998-08-14
52	Daniele	Palmieri	1985-06-21
53	Marta	Battaglia	1991-12-03
54	Giovanni	Rossi	2006-02-15
55	Martina	Bianchi	2005-08-23
56	Luca	Ferrari	2005-12-10
57	Alessia	Romano	2006-03-28
58	Paolo	Moretti	2006-06-04
59	Francesca	Ricci	2005-11-17
60	Andrea	Conti	2006-12-22
61	Giulia	Gallo	2005-05-08
62	Davide	Mancini	2006-01-20
63	Eleonora	Lombardi	2006-07-04
64	Riccardo	Martini	2005-09-17
65	Simona	Rizzo	2006-03-22
66	Antonio	De Angelis	2005-10-05
67	Sofia	De Santis	2006-06-14
68	Giovanni	Esposito	2005-12-31
69	Valentina	Caruso	2006-06-27
70	Enrico	Pellegrini	2005-03-13
71	Anna	Rinaldi	2006-09-09
72	Fabio	Caputo	2005-04-26
73	Silvia	Serra	2006-02-11
74	Eliana	Illiano	2002-06-11
3	Antonio	Lamore	2002-04-02
4	Simone	Iavarone	2003-04-29
6	Silvio	Barra	1985-08-07
75	Porfirio	Tramontana	1976-11-11
76	Lorenzo	Morelli	1990-02-15
77	Giorgia	Lombardi	1993-08-23
78	Luigi	Ferraro	1985-12-10
79	Alessandra	Ricci	1996-03-28
80	Massimo	Santoro	1981-06-04
81	Elisa	Colombo	1994-11-17
82	Gabriele	Conti	1986-12-22
83	Alice	Gallo	1991-05-08
84	Marco	Mancini	1989-01-20
85	Valentina	Lombardi	1982-07-04
86	Paolo	Martini	1998-09-17
87	Sara	Rizzo	1983-03-22
88	Gianluca	De Angelis	1993-10-05
89	Francesca	De Santis	1987-06-14
90	Simone	Esposito	1990-12-31
91	Eleonora	Caruso	1986-06-27
92	Andrea	Pellegrini	1984-03-13
93	Stefania	Rinaldi	1996-09-09
94	Luca	Caputo	1981-04-26
95	Martina	Serra	1998-02-11
96	Giovanni	Mancini	1992-10-14
97	Elena	Russo	1988-01-18
98	Roberto	Longo	1995-07-25
99	Silvia	Ferrari	1983-05-02
100	Antonio	Barbieri	1986-11-29
101	Laura	Farina	1977-07-07
102	Nicola	Ferri	1993-04-15
103	Chiara	Piras	1988-12-08
104	Mattia	Sanna	1995-01-01
105	Valeria	Migliore	1984-09-24
106	Davide	Marchetti	1997-06-12
107	Serena	Bruno	1977-11-22
108	Francesco	Longo	1993-08-30
109	Elisabetta	Marini	1988-04-06
110	Riccardo	Mariani	1994-01-14
111	Sofia	Russo	1981-06-18
112	Lorenzo	Poli	1997-02-25
113	Cristina	D'Amico	1986-10-12
114	Daniele	Ferri	1992-07-01
115	Giulia	Caprioli	1979-03-09
116	Fabio	Pizzuti	1995-11-26
117	Stefano	Bellini	1980-02-19
118	Claudia	Guerrieri	1994-10-04
119	Alessio	Costantini	1989-03-28
120	Elena	Coppola	1998-08-14
121	Andrea	Palmieri	1985-06-21
122	Marta	Battaglia	1991-12-03
\.


--
-- Data for Name: prenotazione; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.prenotazione (idcorsa, idpasseggero, sovrapprezzoprenotazione, sovrapprezzobagagli, idprenotazione, peso_bagaglio, auto) FROM stdin;
10	110	3	10	259	15.25	\N
12	6	3	10	260	9.75	\N
14	60	3	10	261	27.5	\N
11	30	3	10	262	13	\N
18	40	0	10	264	18.25	\N
5	32	3	10	4	5.23	\N
15	85	3	10	265	42.75	\N
19	115	0	10	266	7.5	\N
8	100	0	0	1	3.11	\N
8	98	0	15	178	50.54	\N
8	101	0	10	179	49.54	\N
8	31	0	0	180	5	\N
8	40	0	10	181	7.89	\N
17	25	0	10	267	31	\N
10	75	3	0	183	2.34	\N
10	76	3	0	184	2.34	\N
10	74	3	10	185	5.34	\N
10	74	3	10	186	10.34	\N
11	74	3	10	187	7.34	\N
11	74	3	10	188	7.34	\N
11	122	3	0	189	0.34	\N
11	121	3	15	190	98.34	\N
11	118	3	10	191	43.34	\N
19	74	0	10	192	5.15	\N
18	74	0	10	193	5.15	\N
16	68	3	10	268	20.5	\N
11	6	3	10	196	9.32	\N
19	6	0	10	197	9.32	\N
19	3	0	0	198	3.32	\N
4	3	0	0	199	3.32	\N
4	4	0	0	200	3.32	\N
1	50	3	10	269	14.25	\N
2	55	3	10	270	10.75	\N
4	65	0	10	272	13.75	\N
15	69	3	10	273	37	\N
7	52	3	10	274	22.5	\N
9	57	0	10	275	18.25	\N
18	61	0	10	276	33.75	\N
3	66	3	10	277	19	\N
5	58	3	10	278	25.5	\N
13	75	3	10	263	35	t
13	6	3	10	195	12.32	t
13	60	3	10	271	28.5	t
13	63	3	0	23	3.54	t
1	3	3	10	233	25.5	\N
2	10	3	10	234	30.25	\N
3	22	3	10	235	15.75	\N
4	88	0	10	236	8.5	\N
5	56	3	10	237	50	\N
19	122	0	0	238	5	\N
7	45	3	10	239	12.75	\N
7	78	3	10	240	40.5	\N
8	15	0	10	241	8.25	\N
9	102	0	10	242	17.75	\N
10	33	3	10	243	22	\N
15	70	3	10	244	33.5	\N
16	95	3	10	245	19.25	\N
17	12	0	10	246	45.75	\N
18	55	0	10	247	10	\N
19	90	0	10	248	28.5	\N
\.


--
-- Name: prenotazione_idprenotazione_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.prenotazione_idprenotazione_seq', 278, true);


--
-- Name: sequenza_id_passeggero; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.sequenza_id_passeggero', 122, true);


--
-- Name: acquistointero acquistointero_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.acquistointero
    ADD CONSTRAINT acquistointero_pkey PRIMARY KEY (codbigliettoi, idpasseggero);


--
-- Name: acquistoridotto acquistoridotto_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.acquistoridotto
    ADD CONSTRAINT acquistoridotto_pkey PRIMARY KEY (codbigliettor, idpasseggero);


--
-- Name: bigliettointero bigliettointero_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bigliettointero
    ADD CONSTRAINT bigliettointero_pkey PRIMARY KEY (codbigliettoi);


--
-- Name: bigliettoridotto bigliettoridotto_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bigliettoridotto
    ADD CONSTRAINT bigliettoridotto_pkey PRIMARY KEY (codbigliettor);


--
-- Name: cadenzagiornaliera cadenzagiornaliera_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cadenzagiornaliera
    ADD CONSTRAINT cadenzagiornaliera_pkey PRIMARY KEY (nomecadenzagiornaliera);


--
-- Name: compagniadinavigazione compagniadinavigazione_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.compagniadinavigazione
    ADD CONSTRAINT compagniadinavigazione_pkey PRIMARY KEY (nomecompagnia);


--
-- Name: corsa corsa_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.corsa
    ADD CONSTRAINT corsa_pkey PRIMARY KEY (idcorsa);


--
-- Name: indirizzosocial indirizzosocial_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.indirizzosocial
    ADD CONSTRAINT indirizzosocial_pkey PRIMARY KEY (indirizzo);


--
-- Name: compagniadinavigazione mail; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.compagniadinavigazione
    ADD CONSTRAINT mail UNIQUE (mail);


--
-- Name: natante natante_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.natante
    ADD CONSTRAINT natante_pkey PRIMARY KEY (codnatante);


--
-- Name: navigazione navigazione_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.navigazione
    ADD CONSTRAINT navigazione_pkey PRIMARY KEY (idcorsa, codnatante);


--
-- Name: passeggero passeggero_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.passeggero
    ADD CONSTRAINT passeggero_pkey PRIMARY KEY (idpasseggero);


--
-- Name: prenotazione prenotazione_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.prenotazione
    ADD CONSTRAINT prenotazione_pkey PRIMARY KEY (idprenotazione);


--
-- Name: compagniadinavigazione sitoweb; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.compagniadinavigazione
    ADD CONSTRAINT sitoweb UNIQUE (sitoweb);


--
-- Name: compagniadinavigazione telefono; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.compagniadinavigazione
    ADD CONSTRAINT telefono UNIQUE (telefono);


--
-- Name: prenotazione after_insert_prenotazione; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER after_insert_prenotazione AFTER INSERT ON public.prenotazione FOR EACH ROW EXECUTE FUNCTION public.after_insert_prenotazione();


--
-- Name: corsa aggiungi_navigazione; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER aggiungi_navigazione AFTER INSERT ON public.corsa FOR EACH ROW EXECUTE FUNCTION public.aggiungi_navigazione();


--
-- Name: prenotazione diminuisci_disponibilita; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER diminuisci_disponibilita AFTER INSERT ON public.prenotazione FOR EACH ROW EXECUTE FUNCTION public.diminuisci_disponibilita();


--
-- Name: prenotazione elimina_prenotazione; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER elimina_prenotazione AFTER DELETE ON public.prenotazione FOR EACH ROW EXECUTE FUNCTION public.elimina_prenotazione();


--
-- Name: corsa imposta_disponibilita; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER imposta_disponibilita AFTER INSERT ON public.corsa FOR EACH ROW EXECUTE FUNCTION public.imposta_disponibilita();


--
-- Name: passeggero incrementa_id_passeggero; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER incrementa_id_passeggero BEFORE INSERT ON public.passeggero FOR EACH ROW EXECUTE FUNCTION public.incrementa_id_passeggero();


--
-- Name: natante incrementa_numero_natanti; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER incrementa_numero_natanti AFTER INSERT ON public.natante FOR EACH ROW EXECUTE FUNCTION public.incrementa_numero_natanti();


--
-- Name: corsa modifica_ritardo; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER modifica_ritardo AFTER UPDATE OF ritardo ON public.corsa FOR EACH ROW EXECUTE FUNCTION public.modifica_ritardo();


--
-- Name: prenotazione prezzo_bagaglio; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER prezzo_bagaglio BEFORE INSERT ON public.prenotazione FOR EACH ROW EXECUTE FUNCTION public.prezzo_bagaglio();


--
-- Name: prenotazione setta_sovrapprezzoprenotazione; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER setta_sovrapprezzoprenotazione BEFORE INSERT ON public.prenotazione FOR EACH ROW EXECUTE FUNCTION public.setta_sovrapprezzoprenotazione();


--
-- Name: prenotazione verifica_disponibilita_auto; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER verifica_disponibilita_auto AFTER INSERT ON public.prenotazione FOR EACH ROW EXECUTE FUNCTION public.verifica_disponibilita_auto();


--
-- Name: acquistointero acquistointero_codbigliettoi_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.acquistointero
    ADD CONSTRAINT acquistointero_codbigliettoi_fkey FOREIGN KEY (codbigliettoi) REFERENCES public.bigliettointero(codbigliettoi);


--
-- Name: acquistointero acquistointero_idpasseggero_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.acquistointero
    ADD CONSTRAINT acquistointero_idpasseggero_fkey FOREIGN KEY (idpasseggero) REFERENCES public.passeggero(idpasseggero);


--
-- Name: acquistoridotto acquistoridotto_codbigliettor_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.acquistoridotto
    ADD CONSTRAINT acquistoridotto_codbigliettor_fkey FOREIGN KEY (codbigliettor) REFERENCES public.bigliettoridotto(codbigliettor);


--
-- Name: acquistoridotto acquistoridotto_idpasseggero_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.acquistoridotto
    ADD CONSTRAINT acquistoridotto_idpasseggero_fkey FOREIGN KEY (idpasseggero) REFERENCES public.passeggero(idpasseggero);


--
-- Name: corsa corsa_nomecompagnia_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.corsa
    ADD CONSTRAINT corsa_nomecompagnia_fkey FOREIGN KEY (nomecompagnia) REFERENCES public.compagniadinavigazione(nomecompagnia);


--
-- Name: indirizzosocial indirizzosocial_nomecompagnia_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.indirizzosocial
    ADD CONSTRAINT indirizzosocial_nomecompagnia_fkey FOREIGN KEY (nomecompagnia) REFERENCES public.compagniadinavigazione(nomecompagnia);


--
-- Name: natante natante_nomecompagnia_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.natante
    ADD CONSTRAINT natante_nomecompagnia_fkey FOREIGN KEY (nomecompagnia) REFERENCES public.compagniadinavigazione(nomecompagnia);


--
-- Name: navigazione navigazione_codnatante_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.navigazione
    ADD CONSTRAINT navigazione_codnatante_fkey FOREIGN KEY (codnatante) REFERENCES public.natante(codnatante);


--
-- Name: navigazione navigazione_idcorsa_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.navigazione
    ADD CONSTRAINT navigazione_idcorsa_fkey FOREIGN KEY (idcorsa) REFERENCES public.corsa(idcorsa);


--
-- Name: corsa nomecadenzagiornaliera; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.corsa
    ADD CONSTRAINT nomecadenzagiornaliera FOREIGN KEY (nomecadenzagiornaliera) REFERENCES public.cadenzagiornaliera(nomecadenzagiornaliera);


--
-- Name: prenotazione prenotazione_idcorsa_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.prenotazione
    ADD CONSTRAINT prenotazione_idcorsa_fkey FOREIGN KEY (idcorsa) REFERENCES public.corsa(idcorsa);


--
-- Name: prenotazione prenotazione_idpasseggero_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.prenotazione
    ADD CONSTRAINT prenotazione_idpasseggero_fkey FOREIGN KEY (idpasseggero) REFERENCES public.passeggero(idpasseggero);


--
-- PostgreSQL database dump complete
--

