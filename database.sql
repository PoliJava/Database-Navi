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
				insert into bigliettoridotto values (rand_numb, 10.50 + new.sovrapprezzoprenotazione + new.sovrapprezzobagagli, result_string, new.idpasseggero);
			
			-- se la prenotazine invece viene effettuata durante il periodo in cui la corsa è attiva,
			-- allora non ci sarà nessun sovrapprezzo da aggiungere al prezzo totale
			else 
				insert into bigliettoridotto values (rand_numb, 10.50 + new.sovrapprezzobagagli, result_string, new.idpasseggero);
				
			end if;
		-- l'eta è maggiore di 18 quindi l'inserimento viene effettuato in bigliettointero e acquistointero
		else 
			
			-- lo stesso ragionamento viene utilizzato per il calcolo in bigliettointero
			if (tempo_year > 0 or tempo_month > 0 or tempo_day > 0) then
				insert into bigliettointero values (rand_numb, 15.50 + new.sovrapprezzoprenotazione + new.sovrapprezzobagagli, result_string, new.idpasseggero);
				
			else 
			
				insert into bigliettointero values (rand_numb, 15.50 + new.sovrapprezzobagagli, result_string, new.idpasseggero);
				
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
	
	UPDATE corsa
    SET disponibilita = disponibilita - 1
    WHERE idcorsa = NEW.idcorsa;

    RETURN NEW;
		
end;
$$;


ALTER FUNCTION public.diminuisci_disponibilita() OWNER TO postgres;

--
-- Name: diminuisci_disponibilita_auto(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.diminuisci_disponibilita_auto() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
declare
begin
	
	
	if new.auto = false then
		update corsa
		set disponibilitaauto = disponibilitaauto
		where idcorsa = new.idcorsa;
	else
		update corsa
		set disponibilitaauto = disponibilitaauto -1
		where idcorsa = new.idcorsa;
	end if;
		
		
	
	return new;
end;
$$;


ALTER FUNCTION public.diminuisci_disponibilita_auto() OWNER TO postgres;

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
		
	select codbigliettor into cod_bigl_r from bigliettoridotto where idpasseggero = old.idpasseggero;
	select codbigliettoi into cod_bigl_i from bigliettointero where idpasseggero = old.idpasseggero;
	select datanascita into data_pass from passeggero where idpasseggero = old.idpasseggero;

	-- calcola l'età del passeggero
	select extract(year from age(current_date, data_pass)) into age_pass;
	
	--se l'eta è minore di 18, allora le tuple vengono eliminate in acquistoridotto e bigliettoridotto
	if(age_pass < 18) then
	
		delete from bigliettoridotto where codbigliettor = cod_bigl_r;

	-- l'età è maggiore di 18 quindi le tuple vengono eliminate da acquistointero e bigliettointero
	else 
	
		delete from bigliettointero where codbigliettoi = cod_bigl_i;
		
	end if;
	
	-- aggiornamento della disponibilita dopo la cancellazione di una prenotazione
	if old.auto = false then
		update corsa
		set disponibilita = disponibilita + 1
		where idcorsa = old.idcorsa;
	else 
		update corsa
		set disponibilita = disponibilita + 1
		where idcorsa = old.idcorsa;
		
		update corsa 
		set disponibilitaauto = disponibilitaauto + 1
		where idcorsa = old.idcorsa;
	end if;
	
	return old;
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
		set disponibilita = capienzap
		where idcorsa = new.idcorsa;
		
		update corsa 
		set disponibilitaauto = capienzaa
		where idcorsa = new.idcorsa;
		
	else
	
        -- Altrimenti, la disponibilità è data solo dalla capienza passeggeri
		update corsa
		set disponibilita = capienzap
		where idcorsa = new.idcorsa;
		
		update corsa 
		set disponibilitaauto = 0
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
	disponibilita_auto integer;
begin
	select tiponatante into tipo
	from natante
	where codnatante in (select codnatante 
						from navigazione 
						where idcorsa = new.idcorsa);
	
	select disponibilitaauto into disponibilita_auto
	from corsa 
	where idcorsa = new.idcorsa;
						
	if disponibilita_auto <= 0 then 
		raise exception 'I posti auto sono esauriti.';
	end if;
	
	if new.auto = true and tipo <> 'traghetto' then
		update prenotazione
		set auto = false
		where idcorsa = new.idcorsa;
		
		raise exception 'Impossibile aggiungere l''auto, perchè l''imbarcazione non lo permette';

	end if;
	
	return new;
end;
$$;


ALTER FUNCTION public.verifica_disponibilita_auto() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: bigliettointero; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.bigliettointero (
    codbigliettoi integer NOT NULL,
    prezzo double precision DEFAULT 15.50,
    nominativo character varying(100) NOT NULL,
    idpasseggero integer
);


ALTER TABLE public.bigliettointero OWNER TO postgres;

--
-- Name: bigliettoridotto; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.bigliettoridotto (
    codbigliettor integer NOT NULL,
    prezzo double precision DEFAULT 10.50,
    nominativo character varying(100) NOT NULL,
    idpasseggero integer
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
    nomecadenzagiornaliera character varying(100),
    disponibilitaauto integer
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
    auto boolean DEFAULT false
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
-- Data for Name: bigliettointero; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.bigliettointero (codbigliettoi, prezzo, nominativo, idpasseggero) FROM stdin;
239476	28.5	Riccardo Mariani	110
299585	28.5	Silvio Barra	6
317656	28.5	Christian Villa	30
820400	28.5	Porfirio Tramontana	75
125190	28.5	Vincenzo Marini	40
288802	28.5	Valentina Lombardi	85
971029	25.5	Giulia Caprioli	115
379071	25.5	Anna Rinaldi	25
210870	28.5	Giovanni Esposito	68
49589	28.5	Alessio Costantini	50
771595	25.5	Martina Bianchi	55
378638	28.5	Daniele Palmieri	52
472020	28.5	Giulia Gallo	61
827363	25.5	Antonio De Angelis	66
658466	28.5	Martina Gallo	15
374166	25.5	Luigi Ferraro	78
11787	28.5	Vincenzo Marini	40
424372	25.5	Valeria Migliore	105
929796	28.5	Giovanni Esposito	22
964790	28.5	Simone Esposito	90
520500	28.5	Luca Ferrari	10
9937	25.5	Alessandra Barbieri	33
839718	28.5	Martina Serra	95
409824	28.5	Alessio Costantini	50
985649	28.5	Riccardo Mariani	110
581183	28.5	Valentina Caruso	23
416520	28.5	Porfirio Tramontana	75
568166	28.5	Claudio Russo	42
12269	28.5	Giulia Caprioli	115
123794	25.5	Giovanni Esposito	68
366942	28.5	Christian Villa	30
474309	28.5	Valentina Lombardi	85
119973	25.5	Nicola Ferri	102
912312	28.5	Silvio Barra	6
499305	28.5	Anna Rinaldi	25
416183	25.5	Giulia Caprioli	115
449154	28.5	Porfirio Tramontana	75
502586	25.5	Riccardo Mariani	110
645142	25.5	Alessio Costantini	50
312395	28.5	Vincenzo Marini	40
381160	28.5	Valentina Lombardi	85
910495	28.5	Giulia Caprioli	115
890407	28.5	Anna Rinaldi	25
152156	28.5	Giovanni Esposito	68
905104	28.5	Simone Esposito	90
594804	25.5	Giulia Bianchi	9
511653	25.5	Daniele Palmieri	52
35597	25.5	Giulia Gallo	61
555383	28.5	Antonio De Angelis	66
149359	28.5	Alessio Costantini	50
595753	25.5	Martina Bianchi	55
304605	28.5	Martina Gallo	15
532660	28.5	Luigi Ferraro	78
351933	28.5	Vincenzo Marini	40
718296	28.5	Valeria Migliore	105
457109	28.5	Giovanni Esposito	22
149468	28.5	Simone Esposito	90
631154	28.5	Luca Ferrari	10
905691	25.5	Alessandra Barbieri	33
392380	25.5	Martina Serra	95
998594	25.5	Alessio Costantini	50
582662	28.5	Riccardo Mariani	110
430805	28.5	Antonio Lamore	3
292976	28.5	Porfirio Tramontana	75
748913	28.5	Claudio Russo	42
963868	28.5	Giulia Caprioli	115
358704	25.5	Giovanni Esposito	68
404876	28.5	Christian Villa	30
471273	28.5	Valentina Lombardi	85
860618	28.5	Nicola Ferri	102
491930	28.5	Silvio Barra	6
354134	28.5	Anna Rinaldi	25
487150	28.5	Giulia Caprioli	115
379097	28.5	Porfirio Tramontana	75
830987	28.5	Riccardo Mariani	110
117089	28.5	Alessio Costantini	50
425738	28.5	Vincenzo Marini	40
451538	28.5	Valentina Lombardi	85
201821	28.5	Giulia Caprioli	115
58517	25.5	Anna Rinaldi	25
371551	25.5	Giovanni Esposito	68
95033	25.5	Simone Esposito	90
539327	25.5	Silvio Barra	6
62241	28.5	Daniele Palmieri	52
85978	\N	Valentina Caruso	23
541566	\N	Valentina Caruso	23
860642	\N	Valentina Caruso	23
571198	\N	Valentina Caruso	23
777918	\N	Valentina Caruso	23
497569	\N	Valentina Caruso	23
79083	\N	Valentina Caruso	23
236097	\N	Valentina Caruso	23
56536	\N	Valentina Caruso	23
539875	\N	Valentina Caruso	23
1695	\N	Valentina Caruso	23
455502	\N	Valentina Caruso	23
465287	\N	Valentina Caruso	23
449487	\N	Valentina Caruso	23
699387	\N	Valentina Caruso	23
992331	\N	Valentina Caruso	23
633544	\N	Valentina Caruso	23
656908	\N	Valentina Caruso	23
846166	\N	Valentina Caruso	23
276004	\N	Valentina Caruso	23
77401	\N	Valentina Caruso	23
319414	\N	Valentina Caruso	23
446120	\N	Valentina Caruso	23
587866	\N	Valentina Caruso	23
876763	\N	Valentina Caruso	23
736004	\N	Valentina Caruso	23
358755	\N	Valentina Caruso	23
996281	\N	Valentina Caruso	23
405797	\N	Valentina Caruso	23
49913	\N	Valentina Caruso	23
401901	\N	Valentina Caruso	23
64983	\N	Valentina Caruso	23
246403	\N	Valentina Caruso	23
676673	\N	Valentina Caruso	23
50167	\N	Valentina Caruso	23
341603	\N	Valentina Caruso	23
859966	\N	Valentina Caruso	23
312070	\N	Valentina Caruso	23
268972	\N	Valentina Caruso	23
789751	\N	Valentina Caruso	23
267021	\N	Valentina Caruso	23
453052	\N	Valentina Caruso	23
\.


--
-- Data for Name: bigliettoridotto; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.bigliettoridotto (codbigliettor, prezzo, nominativo, idpasseggero) FROM stdin;
989190	23.5	Andrea Conti	60
686255	23.5	Andrea Conti	60
881581	23.5	Simona Rizzo	65
67493	23.5	Valentina Caruso	69
594920	23.5	Alessia Romano	57
490677	23.5	Paolo Moretti	58
464047	20.5	Sofia De Santis	67
575334	20.5	Paolo Moretti	58
518304	20.5	Andrea Conti	60
132322	23.5	Valentina Caruso	69
439786	23.5	Andrea Conti	60
984739	20.5	Simona Rizzo	65
399789	23.5	Valentina Caruso	69
514698	23.5	Alessia Romano	57
648454	20.5	Paolo Moretti	58
368364	20.5	Andrea Conti	60
712673	23.5	Simona Rizzo	65
812294	20.5	Sofia De Santis	67
966318	23.5	Paolo Moretti	58
814665	23.5	Andrea Conti	60
267917	23.5	Valentina Caruso	69
751163	20.5	Andrea Conti	60
528542	20.5	Simona Rizzo	65
541590	23.5	Valentina Caruso	69
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

COPY public.corsa (idcorsa, nomecompagnia, cittapartenza, cittaarrivo, scalo, ritardo, disponibilita, nomecadenzagiornaliera, disponibilitaauto) FROM stdin;
18	OndAnomala	OLBIA	LIVORNO	\N	canc	0	olbia-livorno lunedi inverno 2024	50
11	OndAnomala	ISCHIA	PONZA	\N	30'	56	ischia-ponza estate 2024	0
1	NavItalia	CAPRI	CASTELLAMMARE	NAPOLI	\N	22	capri-castellammare primavera/estate 2024	0
2	OndAnomala	NAPOLI	ISCHIA	\N	\N	55	napoli-ischia primavera2024	0
4	NaviExpress	SALERNO	CAGLIARI	\N	\N	47	salerno-cagliari weekend inverno 2024	0
10	OndAnomala	CIVITAVECCHIA	OLBIA	\N	\N	56	civitavecchia-olbia infrasettimanale autunno 2024	0
6	NaviExpress	GENOVA	NAPOLI	\N	10'	47	genova-napoli lun-mer-ven primavera 2024	0
7	NavItalia	CASTELLAMMARE	CAPRI	NAPOLI	\N	45	castellammare-capri primavera/estate 2024	0
8	NavItalia	CAPRI	NAPOLI	\N	\N	22	capri-napoli febbraio-settembre 2024	0
9	NavItalia	NAPOLI	CAPRI	\N	\N	20	napoli-capri febbraio-settembre 2024	0
17	NaviExpress	CAGLIARI	SALERNO	\N	\N	94	cagliari-salerno bisettimanale inverno 2024	47
16	MareChiaroT	VENTOTENE	NAPOLI	\N	\N	93	ventotene-napoli estate 2024	47
5	NaviExpress	CIVITAVECCHIA	OLBIA	\N	\N	92	civitavecchia-olbia infrasettimanale autunno 2024	45
13	MareChiaroT	NAPOLI	PANAREA	\N	\N	92	napoli-panarea estate 2024	45
15	MareChiaroT	NAPOLI	VENTOTENE	\N	\N	94	napoli-ventotene estate 2024	48
14	MareChiaroT	PANAREA	NAPOLI	\N	\N	91	panarea-napoli estate 2024	45
12	OndAnomala	PONZA	ISCHIA	\N	\N	91	ponza-ischia estate 2024	46
19	OndAnomala	LIVORNO	OLBIA	\N	\N	47	livorno-olbia lunedi inverno 2024	0
3	NavItalia	POZZUOLI	ISCHIA	PROCIDA	\N	141	corsa estiva 2024 pozzuoli-procida-ischia	45
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
1	3
10	12
11	12
12	9
13	13
14	13
15	13
16	13
17	7
18	9
19	9
2	11
3	6
4	5
5	7
6	5
7	4
8	3
9	3
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
12	110	3	10	1	15.25	f
12	6	3	10	2	9.75	f
14	60	3	10	3	27.5	f
11	30	3	10	4	13	f
13	75	3	10	5	35	f
6	40	3	10	6	18.25	f
15	85	3	10	7	42.75	f
19	115	0	10	8	7.5	f
17	25	0	10	9	31	f
16	68	3	10	10	20.5	f
11	50	3	10	11	14.25	f
2	55	0	10	12	10.75	f
3	60	3	10	13	28.5	f
14	65	3	10	14	13.75	f
15	69	3	10	15	37	f
16	52	3	10	16	22.5	f
7	57	3	10	17	18.25	f
12	61	3	10	18	33.75	f
9	66	0	10	19	19	f
10	58	3	10	20	25.5	f
1	15	3	10	21	25.5	f
2	78	0	10	22	30.25	f
3	40	3	10	23	15.75	f
4	105	0	10	24	8.5	f
5	22	3	10	25	50	f
7	90	3	10	26	12.75	f
7	10	3	10	27	40.5	f
8	67	0	10	28	8.25	f
9	33	0	10	29	17.75	f
10	95	3	10	30	22	f
11	50	3	10	31	12.75	f
12	110	3	10	32	40.5	f
13	23	3	10	33	8.25	f
14	75	3	10	34	17.75	f
15	42	3	10	35	22	f
16	115	3	10	36	25.5	f
17	68	0	10	37	33.5	f
6	30	3	10	38	19.25	f
19	58	0	10	39	45.75	f
1	85	3	10	40	10	f
2	102	0	10	41	28.5	f
3	6	3	10	42	15.25	f
4	60	0	10	43	9.75	f
5	25	3	10	44	27.5	f
2	115	0	10	45	13	f
7	75	3	10	46	35	f
8	110	0	10	47	18.25	f
9	50	0	10	48	42.75	f
10	69	3	10	49	7.5	f
11	40	3	10	50	18.25	f
12	85	3	10	51	42.75	f
13	115	3	10	52	7.5	f
14	25	3	10	53	31	f
15	68	3	10	54	20.5	f
16	90	3	10	55	14.25	f
17	9	0	10	56	10.75	f
6	60	3	10	57	28.5	f
19	65	0	10	58	13.75	f
1	69	3	10	59	37	f
2	52	0	10	60	22.5	f
3	57	3	10	61	18.25	f
4	61	0	10	62	33.75	f
5	66	3	10	63	19	f
9	58	0	10	64	25.5	f
7	50	3	10	65	14.25	f
8	55	0	10	66	10.75	f
9	60	0	10	67	28.5	f
10	65	3	10	68	13.75	f
12	15	3	10	69	25.5	t
12	78	3	10	70	30.25	t
12	40	3	10	71	15.75	t
13	105	3	10	72	8.5	t
14	22	3	10	73	50	t
15	90	3	10	74	12.75	t
16	10	3	10	75	40.5	t
17	67	0	10	76	8.25	t
19	33	0	10	77	17.75	t
19	95	0	10	78	22	t
17	50	0	10	79	12.75	t
14	110	3	10	80	40.5	t
13	3	3	10	81	8.25	t
13	75	3	10	82	17.75	t
14	42	3	10	83	22	t
16	115	3	10	84	25.5	t
17	68	0	10	85	33.5	t
16	30	3	10	86	19.25	t
14	58	3	10	87	45.75	t
3	85	3	10	88	10	t
3	102	3	10	89	28.5	t
3	6	3	10	90	15.25	t
5	60	3	10	91	9.75	t
5	25	3	10	92	27.5	t
5	115	3	10	93	13	t
5	75	3	10	94	35	t
5	110	3	10	95	18.25	t
15	50	3	10	96	42.75	t
14	69	3	10	97	7.5	t
13	40	3	10	98	18.25	t
12	85	3	10	99	42.75	t
13	115	3	10	100	7.5	t
19	25	0	10	101	31	t
19	68	0	10	102	20.5	t
19	90	0	10	103	14.25	t
19	6	0	10	104	10.75	t
19	60	0	10	105	28.5	t
19	65	0	10	106	13.75	t
3	69	3	10	107	37	t
3	52	3	10	108	22.5	t
19	23	0	\N	110	\N	t
19	23	0	\N	111	\N	t
19	23	0	\N	112	\N	t
19	23	0	\N	113	\N	t
19	23	0	\N	114	\N	t
19	23	0	\N	115	\N	t
19	23	0	\N	116	\N	t
19	23	0	\N	117	\N	t
19	23	0	\N	118	\N	t
19	23	0	\N	119	\N	t
19	23	0	\N	120	\N	t
19	23	0	\N	121	\N	t
19	23	0	\N	122	\N	t
19	23	0	\N	123	\N	t
19	23	0	\N	124	\N	t
19	23	0	\N	125	\N	t
19	23	0	\N	126	\N	t
19	23	0	\N	127	\N	t
19	23	0	\N	128	\N	t
19	23	0	\N	129	\N	t
19	23	0	\N	130	\N	t
19	23	0	\N	131	\N	t
19	23	0	\N	132	\N	t
19	23	0	\N	133	\N	t
19	23	0	\N	134	\N	t
19	23	0	\N	135	\N	t
19	23	0	\N	136	\N	t
19	23	0	\N	137	\N	t
19	23	0	\N	138	\N	t
19	23	0	\N	139	\N	t
19	23	0	\N	140	\N	t
19	23	0	\N	141	\N	t
19	23	0	\N	142	\N	t
19	23	0	\N	143	\N	t
19	23	0	\N	144	\N	t
19	23	0	\N	145	\N	t
19	23	0	\N	146	\N	t
19	23	0	\N	147	\N	t
19	23	0	\N	148	\N	t
19	23	0	\N	149	\N	t
19	23	0	\N	150	\N	t
19	23	0	\N	151	\N	t
\.


--
-- Name: prenotazione_idprenotazione_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.prenotazione_idprenotazione_seq', 155, true);


--
-- Name: sequenza_id_passeggero; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.sequenza_id_passeggero', 122, true);


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
-- Name: prenotazione diminuisci_disponibilita_auto; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER diminuisci_disponibilita_auto AFTER INSERT ON public.prenotazione FOR EACH ROW EXECUTE FUNCTION public.diminuisci_disponibilita_auto();


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

CREATE TRIGGER verifica_disponibilita_auto BEFORE INSERT ON public.prenotazione FOR EACH ROW EXECUTE FUNCTION public.verifica_disponibilita_auto();


--
-- Name: corsa corsa_nomecompagnia_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.corsa
    ADD CONSTRAINT corsa_nomecompagnia_fkey FOREIGN KEY (nomecompagnia) REFERENCES public.compagniadinavigazione(nomecompagnia);


--
-- Name: bigliettointero idpasseggero; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bigliettointero
    ADD CONSTRAINT idpasseggero FOREIGN KEY (idpasseggero) REFERENCES public.passeggero(idpasseggero);


--
-- Name: bigliettoridotto idpasseggero; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bigliettoridotto
    ADD CONSTRAINT idpasseggero FOREIGN KEY (idpasseggero) REFERENCES public.passeggero(idpasseggero);


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

