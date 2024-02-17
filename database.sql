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
	
	select disponibilitapasseggero into disponibilita_corsa 
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
										 from tratta
										 where idtratta in (select idtratta
														   from corsa
														   where idcorsa = new.idcorsa));
		
		-- la funzione concat concatena una stringa ad un'altra separata da uno spazio
		result_string := concat(nome_pass, ' ', cognome_pass);
		
		-- viene utilizzata la funzione random per generare un codice biglietto in maniera casuale. 
		-- la funzione floor viene utilizzata per indicare che i numeri devono essere interi
		rand_numb := floor(random() * 1000000) :: integer + 1;
		
		-- queste istruzioni servono a calcolare la differenza tra una data ed un'altra.
		-- viene utilizzata la funzione date_part per estrarre l'anno, il mese o il giorno da una data
		-- e successivamente la funzione age calcola la differenza (e quindi l'eta) tra i due valori.
		select date_part('year', age(current_date, data_pass)) into age_pass;
		
		select date_part('year', age(data_corsa, current_date)) into tempo_year;
		select date_part('month', age(data_corsa, current_date)) into tempo_month;
		select date_part('day', age(data_corsa, current_date)) into tempo_day;

		-- se l'eta è minore di 18 anni, verrà effettuato un inserimento in bigliettoridotto
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
		-- l'eta è maggiore di 18 quindi l'inserimento viene effettuato in bigliettointero
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

COMMENT ON FUNCTION public.after_insert_prenotazione() IS '-- funzione che, dopo l''inserimento di una tupla in prenotazione, attiva il trigger che permette di aggiungere una tupla corrispondente in bigliettoridotto se l''età è minore di 18, oppure in bigliettointero se l''età è maggiore di 18. Questa funzione inoltre permette di indicare l''eventuale sovrapprezzo della prenotazione o il sovrapprezzo dei bagagli, e di diminuire la disponibilità nella tabella corsa';


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
		INSERT INTO navigazione VALUES (NEW.idtratta, cod_natante);
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
    SET disponibilitapasseggero = disponibilitapasseggero - 1
    WHERE idcorsa = NEW.idcorsa;
	
	if new.auto = false then
		update corsa
		set disponibilitaauto = disponibilitaauto
		where idcorsa = new.idcorsa;
	else
		update corsa
		set disponibilitaauto = disponibilitaauto -1
		where idcorsa = new.idcorsa;
	end if;
		

    RETURN NEW;
		
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
		set disponibilitapasseggero = disponibilitapasseggero + 1
		where idcorsa = old.idcorsa;
	else 
		update corsa
		set disponibilitapasseggero = disponibilitapasseggero + 1
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
	
	-- Seleziona la capienza passeggeri, la capienza automezzi e il tipo del natante associato alla corsa
	select capienzapasseggeri, tiponatante, capienzaautomezzi into capienzap, tipo_natante, capienzaa
	from natante
	where codnatante in (select codnatante
						from navigazione
						where idtratta in (select idtratta 
										  from corsa
										  where idcorsa = new.idcorsa));
	
	-- Verifica il tipo del natante e imposta la disponibilità della corsa di conseguenza
	if tipo_natante = 'traghetto' then
	
        -- Se il natante è un traghetto, la disponibilità è data dalla somma della capienza passeggeri e automezzi
		update corsa 
		set disponibilitapasseggero = capienzap
		where idcorsa = new.idcorsa;
		
		update corsa 
		set disponibilitaauto = capienzaa
		where idcorsa = new.idcorsa;
		
	else
	
        -- Altrimenti, la disponibilità è data solo dalla capienza passeggeri
		update corsa
		set disponibilitapasseggero = capienzap
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
-- Name: insert_into_corsa(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.insert_into_corsa() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    capienzap INTEGER; --capienza passeggeri
    disponibilitapasseggero integer;
    disponibilitaauto integer;
    capienzaa INTEGER; --capienza automezzi
    tipo_natante varchar(50); --tipo del natante
	giornosett cadenzagiornaliera.nomecadenzagiornaliera%type;
	giorni text[];
	giorno text;
    giorno_numero integer;
	data_giorno date;
	day_of integer;

    
BEGIN
    -- Seleziona la capienza passeggeri, la capienza automezzi e il tipo del natante associato alla corsa
    select capienzapasseggeri, tiponatante, capienzaautomezzi into capienzap, tipo_natante, capienzaa
    from natante
    where codnatante in (select codnatante
                        from navigazione
                        where idtratta = new.idtratta);

    if tipo_natante = 'traghetto' then
        -- Se il natante è un traghetto, la disponibilità è data dalla somma della capienza passeggeri e automezzi
        disponibilitapasseggero = capienzap;
        disponibilitaauto = capienzaa;
    else
        -- Altrimenti, la disponibilità è data solo dalla capienza passeggeri
        disponibilitapasseggero = capienzap;
        disponibilitaauto = 0;
    end if;
    
	select giornosettimanale into giornosett
	from cadenzagiornaliera
	where nomecadenzagiornaliera = new.nomecadenzagiornaliera;
	
	giorni := string_to_array(giornosett, ', ');	
	
	FOR i IN 1..array_length(giorni, 1) LOOP
        giorno := giorni[i];
		giorno_numero := CASE
            WHEN giorno = 'lunedi' THEN 2
            WHEN giorno = 'martedi' THEN 3
            WHEN giorno = 'mercoledi' THEN 4
            WHEN giorno = 'giovedi' THEN 5
            WHEN giorno = 'venerdi' THEN 6
            WHEN giorno = 'sabato' THEN 7
            WHEN giorno = 'domenica' THEN 1
        END;
		
        FOR data_giorno IN 
			SELECT generate_series(datainizio, datafine, '1 day'::interval) 
			FROM CADENZAGIORNALIERA 
			WHERE nomeCadenzaGiornaliera = new.nomecadenzagiornaliera 
				
		LOOP
			
			 IF giorno_numero =  to_char(data_giorno, 'D')::integer THEN
                INSERT INTO CORSA (Disponibilitapasseggero, Disponibilitaauto, Giorno, idTratta)
                VALUES (disponibilitapasseggero, disponibilitaauto, data_giorno, NEW.IdTratta);
            END IF;
			
        END LOOP;
    END LOOP;
	
   
RETURN NEW;
END;
$$;


ALTER FUNCTION public.insert_into_corsa() OWNER TO postgres;

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
			SET disponibilitapasseggero = 0
			WHERE idcorsa = NEW.idcorsa;
			
			UPDATE corsa
			SET disponibilitaauto = 0
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

	select giorno into data_corsa 
	from corsa
	where idcorsa = new.idcorsa;
									
	select extract(year from age(data_corsa, current_date)) into tempo_year;
	select extract(month from age(data_corsa, current_date)) into tempo_month;
	select extract(day from age(data_corsa, current_date)) into tempo_day;
	
	-- se la prenotazione viene effettuata prima della data in cui viene prenotata, allora il sovrapprezzo è settato a 3
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
						where idtratta in (select idtratta
										  from corsa
										  where idcorsa = new.idcorsa));

	select disponibilitaauto into disponibilita_auto
	from corsa 
	where idcorsa = new.idcorsa and idtratta in (select idtratta
											   from navigazione
											   where codnatante in (select codnatante
																   from natante
																   where tiponatante = 'traghetto'));

	if disponibilita_auto = 0 then
		raise exception 'I posti auto sono esauriti.';
	end if;
	
	if new.auto = true and tipo <> 'traghetto' then
		update prenotazione
		set auto = false
		where idcorsa = new.idcorsa;
		
		-- nel caso una prenotazione sia fatta su un tipo di nave che non ha posti auto, c'è un'exception:
		raise exception 'Impossibile aggiungere l''auto, perchè l''imbarcazione non lo permette';
		
	elsif new.auto = false then
	
		update prenotazione
		set auto = false
		where idcorsa = new.idcorsa;
		
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
-- Name: id_corsa_sequence; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.id_corsa_sequence
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.id_corsa_sequence OWNER TO postgres;

--
-- Name: corsa; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.corsa (
    idcorsa integer DEFAULT nextval('public.id_corsa_sequence'::regclass) NOT NULL,
    ritardo character varying(4),
    disponibilitaauto integer,
    disponibilitapasseggero integer,
    giorno date,
    idtratta integer
);


ALTER TABLE public.corsa OWNER TO postgres;

--
-- Name: id_tratta_sequence; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.id_tratta_sequence
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.id_tratta_sequence OWNER TO postgres;

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
    CONSTRAINT ck_tiponatante CHECK (((tiponatante)::text = ANY (ARRAY[('traghetto'::character varying)::text, ('aliscafo'::character varying)::text, ('motonave'::character varying)::text, ('altro'::character varying)::text])))
);


ALTER TABLE public.natante OWNER TO postgres;

--
-- Name: navigazione; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.navigazione (
    idtratta integer NOT NULL,
    codnatante character varying(15) NOT NULL
);


ALTER TABLE public.navigazione OWNER TO postgres;

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
-- Name: passeggero; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.passeggero (
    idpasseggero integer DEFAULT nextval('public.sequenza_id_passeggero'::regclass) NOT NULL,
    nome character varying(50) NOT NULL,
    cognome character varying(50) NOT NULL,
    datanascita date NOT NULL
);


ALTER TABLE public.passeggero OWNER TO postgres;

--
-- Name: prenotazione; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.prenotazione (
    idpasseggero integer NOT NULL,
    sovrapprezzoprenotazione double precision DEFAULT 3.00,
    sovrapprezzobagagli double precision,
    idprenotazione integer NOT NULL,
    peso_bagaglio double precision,
    auto boolean DEFAULT false,
    idcorsa integer
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
-- Name: tratta; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tratta (
    idtratta integer DEFAULT nextval('public.id_tratta_sequence'::regclass) NOT NULL,
    cittapartenza character varying(30) NOT NULL,
    cittaarrivo character varying(30) NOT NULL,
    scalo character varying(30) DEFAULT NULL::character varying,
    nomecompagnia character varying(30),
    nomecadenzagiornaliera character varying(100)
);


ALTER TABLE public.tratta OWNER TO postgres;

--
-- Name: prenotazione idprenotazione; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.prenotazione ALTER COLUMN idprenotazione SET DEFAULT nextval('public.prenotazione_idprenotazione_seq'::regclass);


--
-- Data for Name: bigliettointero; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.bigliettointero (codbigliettoi, prezzo, nominativo, idpasseggero) FROM stdin;
292538	18.5	Valentina Caruso	23
384489	28.5	Riccardo Mariani	110
843389	18.5	Sofia Russo	111
651237	28.5	Alessia Romano	11
860190	28.5	Francesca Ricci	13
940736	18.5	Francesca Ricci	13
657304	18.5	Martina Gallo	15
499784	18.5	Riccardo Martini	18
887428	18.5	Luca Ferrari	10
705672	18.5	Antonio De Angelis	20
33988	18.5	Dave Gahan	127
23317	18.5	David Bowie	126
377008	18.5	Marta Battaglia	122
621004	18.5	Andrea Palmieri	121
19843	18.5	Elena Coppola	120
985818	18.5	Riccardo Mariani	110
347514	18.5	Alice Gallo	83
189129	18.5	Porfirio Tramontana	75
352604	18.5	Alessandra Ricci	79
191891	18.5	Alessandra Ricci	79
644121	28.5	Anna Rinaldi	25
883248	28.5	Anna Rinaldi	25
229740	28.5	Fabio Caputo	26
3064	28.5	Fabio Caputo	26
367364	28.5	Martina Gallo	15
564845	18.5	Martina Gallo	15
886032	18.5	Eleonora Lombardi	17
400260	18.5	Eleonora Lombardi	17
559046	18.5	Simona Rizzo	19
496234	18.5	Antonio De Angelis	20
45382	18.5	Antonio De Angelis	20
425963	18.5	Vincenzo Marini	40
447239	18.5	Serena Mariani	41
92270	28.5	Serena Mariani	41
536941	28.5	Claudio Russo	42
804445	28.5	Alessio Costantini	50
499955	28.5	Giovanni Esposito	68
416593	28.5	Riccardo Martini	64
374912	28.5	Silvia Serra	73
488947	28.5	Alice Gallo	83
987098	28.5	Paolo Martini	86
985549	28.5	Francesca De Santis	89
353232	28.5	Silvia Ferrari	99
128409	28.5	Elisabetta Marini	109
723828	28.5	Alessio Costantini	119
578574	28.5	Elena Piras	29
711601	28.5	Elena Piras	29
766894	28.5	Antonio Lamore	3
434743	28.5	Antonio Lamore	3
105271	28.5	Simone Iavarone	4
551986	28.5	Silvio Barra	6
907189	28.5	Eleonora Lombardi	17
966188	28.5	Marco Rossi	8
690437	28.5	Giulia Bianchi	9
359123	28.5	Luca Ferrari	10
241933	28.5	Alessia Romano	11
778993	28.5	Paolo Moretti	12
875940	28.5	Francesca Ricci	13
153266	28.5	Andrea Conti	14
915487	28.5	Martina Gallo	15
526743	28.5	Davide Mancini	16
469859	28.5	Eleonora Lombardi	17
438711	28.5	Riccardo Martini	18
31617	28.5	Simona Rizzo	19
841846	28.5	Antonio De Angelis	20
834597	28.5	Sofia De Santis	21
333659	28.5	Giovanni Esposito	22
726741	28.5	Valentina Caruso	23
108091	18.5	Enrico Pellegrini	24
832837	28.5	Anna Rinaldi	25
418831	18.5	Fabio Caputo	26
953605	28.5	Silvia Serra	27
737239	18.5	Matteo Galli	28
472289	28.5	Elena Piras	29
281130	18.5	Christian Villa	30
849710	28.5	Laura Costa	31
534327	18.5	Michele Leone	32
219456	28.5	Alessandra Barbieri	33
165640	18.5	Stefano Farina	34
106833	28.5	Beatrice Sanna	35
555856	18.5	Gabriele Migliore	36
961902	28.5	Linda Marchetti	37
598786	18.5	Massimo Bruno	38
76635	28.5	Federica Longo	39
300067	18.5	Vincenzo Marini	40
761283	28.5	Serena Mariani	41
939970	18.5	Claudio Russo	42
751119	28.5	Elisa Poli	43
573882	18.5	Gabriel D'Amico	44
965774	28.5	Valeria Ferri	45
748612	18.5	Tommaso Caprioli	46
857808	28.5	Ilaria Pizzuti	47
799247	18.5	Guido Bellini	48
97910	28.5	Miriam Guerrieri	49
871466	18.5	Alessio Costantini	50
526782	18.5	Sara Coppola	51
846528	28.5	Daniele Palmieri	52
9074	18.5	Marta Battaglia	53
608090	28.5	Giovanni Rossi	54
943513	18.5	Martina Bianchi	55
680435	28.5	Luca Ferrari	56
298375	28.5	Francesca Ricci	59
435004	28.5	Giulia Gallo	61
747892	28.5	Davide Mancini	62
298108	28.5	Riccardo Martini	64
275708	28.5	Antonio De Angelis	66
303934	28.5	Giovanni Esposito	68
443241	28.5	Enrico Pellegrini	70
574072	28.5	Fabio Caputo	72
994617	28.5	Silvia Serra	73
425718	28.5	Eliana Illiano	74
392037	28.5	Porfirio Tramontana	75
431708	28.5	Lorenzo Morelli	76
537499	28.5	Giorgia Lombardi	77
905387	28.5	Luigi Ferraro	78
677801	28.5	Alessandra Ricci	79
534739	28.5	Massimo Santoro	80
820457	28.5	Elisa Colombo	81
4234	28.5	Gabriele Conti	82
836920	28.5	Alice Gallo	83
779877	28.5	Marco Mancini	84
67251	28.5	Valentina Lombardi	85
539283	28.5	Paolo Martini	86
532654	28.5	Sara Rizzo	87
279280	28.5	Gianluca De Angelis	88
987202	28.5	Francesca De Santis	89
715186	28.5	Simone Esposito	90
908803	28.5	Eleonora Caruso	91
751685	28.5	Andrea Pellegrini	92
765326	28.5	Stefania Rinaldi	93
152937	28.5	Luca Caputo	94
551943	28.5	Martina Serra	95
960868	28.5	Giovanni Mancini	96
71586	28.5	Elena Russo	97
164214	28.5	Roberto Longo	98
573804	28.5	Silvia Ferrari	99
756268	28.5	Antonio Barbieri	100
485309	28.5	Laura Farina	101
935050	28.5	Nicola Ferri	102
269577	28.5	Chiara Piras	103
36189	28.5	Mattia Sanna	104
767406	28.5	Valeria Migliore	105
261893	28.5	Davide Marchetti	106
20547	28.5	Serena Bruno	107
833357	28.5	Francesco Longo	108
307503	28.5	Elisabetta Marini	109
754591	33.5	Riccardo Mariani	110
237213	28.5	Sofia Russo	111
81099	33.5	Lorenzo Poli	112
339906	28.5	Cristina D'Amico	113
973646	33.5	Daniele Ferri	114
56990	28.5	Giulia Caprioli	115
991535	33.5	Fabio Pizzuti	116
469343	28.5	Stefano Bellini	117
134859	33.5	Claudia Guerrieri	118
558148	28.5	Alessio Costantini	119
204889	33.5	Elena Coppola	120
825209	28.5	Andrea Palmieri	121
874806	33.5	Marta Battaglia	122
90310	28.5	Kurt Cobain	123
165059	33.5	Mick Jagger	124
696663	28.5	Freddie Mercury	125
595019	33.5	David Bowie	126
698168	28.5	Dave Gahan	127
561016	28.5	Andrea Palmieri	121
144335	33.5	Francesca Ricci	13
\.


--
-- Data for Name: bigliettoridotto; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.bigliettoridotto (codbigliettor, prezzo, nominativo, idpasseggero) FROM stdin;
488942	13.5	Giovanni Di Meo	128
598499	23.5	Paolo Moretti	58
588671	23.5	Paolo Moretti	58
333610	23.5	Eleonora Lombardi	63
533598	23.5	Giovanni Di Meo	128
450461	13.5	Alessia Romano	57
344783	23.5	Paolo Moretti	58
103187	23.5	Andrea Conti	60
225831	23.5	Eleonora Lombardi	63
326007	23.5	Simona Rizzo	65
9605	23.5	Sofia De Santis	67
536418	23.5	Valentina Caruso	69
839325	23.5	Anna Rinaldi	71
152369	28.5	Giovanni Di Meo	128
\.


--
-- Data for Name: cadenzagiornaliera; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.cadenzagiornaliera (datainizio, datafine, giornosettimanale, orariopartenza, orarioarrivo, nomecadenzagiornaliera) FROM stdin;
2024-02-01	2024-04-30	lunedi - mercoledi	10:00:00	11:00:00	napoli-ischia primavera2024
2023-12-15	2024-02-29	sabato - domenica	09:30:00	12:00:00	salerno-cagliari weekend inverno 2024
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
2024-05-15	2024-09-15	sabato	10:30:00	11:30:00	corsa estiva 2024 pozzuoli-procida-ischia
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

COPY public.corsa (idcorsa, ritardo, disponibilitaauto, disponibilitapasseggero, giorno, idtratta) FROM stdin;
51	\N	49	99	2024-10-15	2
52	\N	50	99	2024-10-22	2
53	\N	49	99	2024-10-29	2
101	\N	0	59	2024-07-30	3
54	\N	50	99	2024-11-05	2
102	\N	0	59	2024-08-06	3
55	\N	49	99	2024-11-12	2
103	\N	0	59	2024-08-13	3
163	\N	0	60	2024-06-04	4
56	\N	50	99	2024-11-19	2
104	\N	0	59	2024-08-20	3
57	\N	49	99	2024-11-26	2
58	\N	50	99	2024-12-03	2
105	\N	0	59	2024-08-27	3
59	\N	49	99	2024-09-25	2
106	\N	0	59	2024-09-03	3
60	\N	50	99	2024-10-02	2
61	\N	49	99	2024-10-09	2
107	\N	0	59	2024-09-10	3
108	\N	0	59	2024-09-17	3
62	\N	50	99	2024-10-16	2
164	\N	0	60	2024-06-11	4
109	\N	0	59	2024-09-24	3
110	\N	0	59	2024-06-06	3
111	\N	0	59	2024-06-13	3
63	\N	49	99	2024-10-23	2
112	\N	0	59	2024-06-20	3
113	\N	0	59	2024-06-27	3
233	\N	50	100	2024-06-04	5
114	\N	0	59	2024-07-04	3
2	\N	1	50	2024-06-08	1
64	\N	50	99	2024-10-30	2
165	\N	0	60	2024-06-18	4
65	\N	49	99	2024-11-06	2
166	\N	0	60	2024-06-25	4
66	\N	50	99	2024-11-13	2
67	\N	49	99	2024-11-20	2
68	\N	50	99	2024-11-27	2
167	\N	0	60	2024-07-02	4
69	\N	49	99	2024-12-04	2
93	\N	0	58	2024-06-04	3
94	\N	0	59	2024-06-11	3
234	\N	50	100	2024-06-11	5
95	\N	0	59	2024-06-18	3
168	\N	0	60	2024-07-09	4
96	\N	0	59	2024-06-25	3
3	\N	49	98	2024-06-15	1
169	\N	0	60	2024-07-16	4
97	\N	0	59	2024-07-02	3
170	\N	0	60	2024-07-23	4
235	\N	50	100	2024-06-18	5
171	\N	0	60	2024-07-30	4
172	\N	0	60	2024-08-06	4
1	canc	0	0	2024-06-01	1
173	\N	0	60	2024-08-13	4
236	\N	50	100	2024-06-25	5
174	\N	0	60	2024-08-20	4
175	\N	0	60	2024-08-27	4
176	\N	0	60	2024-09-03	4
237	\N	50	100	2024-07-02	5
4	\N	49	99	2024-06-22	1
238	\N	50	100	2024-07-09	5
239	\N	50	100	2024-07-16	5
5	\N	50	99	2024-06-29	1
240	\N	50	100	2024-07-23	5
98	\N	0	59	2024-07-09	3
241	\N	50	100	2024-07-30	5
6	\N	49	99	2024-07-06	1
7	\N	50	99	2024-07-13	1
99	\N	0	59	2024-07-16	3
8	\N	49	99	2024-07-20	1
9	\N	50	99	2024-07-27	1
100	45'	0	59	2024-07-23	3
10	\N	49	99	2024-08-03	1
115	\N	0	59	2024-07-11	3
70	\N	50	99	2024-09-26	2
71	\N	49	99	2024-10-03	2
116	\N	0	59	2024-07-18	3
117	\N	0	59	2024-07-25	3
177	\N	0	60	2024-09-10	4
118	\N	0	59	2024-08-01	3
119	\N	0	59	2024-08-08	3
120	\N	0	59	2024-08-15	3
121	\N	0	59	2024-08-22	3
122	\N	0	59	2024-08-29	3
178	\N	0	60	2024-09-17	4
123	\N	0	59	2024-09-05	3
124	\N	0	59	2024-09-12	3
125	\N	0	59	2024-09-19	3
242	\N	50	100	2024-08-06	5
126	\N	0	59	2024-09-26	3
179	\N	0	60	2024-09-24	4
180	\N	0	60	2024-06-06	4
72	\N	50	99	2024-10-10	2
181	\N	0	60	2024-06-13	4
243	\N	50	100	2024-08-13	5
182	\N	0	60	2024-06-20	4
131	\N	0	60	2024-06-29	3
132	\N	0	60	2024-07-06	3
133	\N	0	60	2024-07-13	3
183	\N	0	60	2024-06-27	4
134	\N	0	60	2024-07-20	3
135	\N	0	60	2024-07-27	3
127	\N	0	59	2024-06-01	3
136	\N	0	60	2024-08-03	3
184	\N	0	60	2024-07-04	4
137	\N	0	60	2024-08-10	3
138	\N	0	60	2024-08-17	3
244	\N	50	100	2024-08-20	5
139	\N	0	60	2024-08-24	3
185	\N	0	60	2024-07-11	4
140	\N	0	60	2024-08-31	3
141	\N	0	60	2024-09-07	3
142	\N	0	60	2024-09-14	3
186	\N	0	60	2024-07-18	4
143	\N	0	60	2024-09-21	3
144	\N	0	60	2024-09-28	3
145	\N	0	60	2024-06-02	3
187	\N	0	60	2024-07-25	4
146	\N	0	60	2024-06-09	3
147	\N	0	60	2024-06-16	3
245	\N	50	100	2024-08-27	5
148	\N	0	60	2024-06-23	3
188	\N	0	60	2024-08-01	4
149	\N	0	60	2024-06-30	3
189	\N	0	60	2024-08-08	4
33	\N	50	99	2024-09-08	1
190	\N	0	60	2024-08-15	4
246	\N	50	100	2024-09-03	5
191	\N	0	60	2024-08-22	4
192	\N	0	60	2024-08-29	4
73	\N	49	99	2024-10-17	2
193	\N	0	60	2024-09-05	4
247	\N	50	100	2024-09-10	5
194	\N	0	60	2024-09-12	4
195	\N	0	60	2024-09-19	4
34	\N	49	99	2024-09-15	1
196	\N	0	60	2024-09-26	4
248	\N	50	100	2024-09-17	5
197	\N	0	60	2024-06-01	4
198	\N	0	60	2024-06-08	4
128	\N	0	59	2024-06-08	3
199	\N	0	60	2024-06-15	4
249	\N	50	100	2024-09-24	5
35	\N	50	99	2024-09-22	1
250	\N	50	100	2024-06-01	5
74	\N	50	99	2024-10-24	2
251	\N	50	100	2024-06-08	5
36	\N	49	99	2024-09-29	1
252	\N	50	100	2024-06-15	5
253	\N	50	100	2024-06-22	5
75	\N	49	99	2024-10-31	2
254	\N	50	100	2024-06-29	5
129	\N	0	59	2024-06-15	3
255	\N	50	100	2024-07-06	5
76	\N	50	99	2024-11-07	2
256	\N	50	100	2024-07-13	5
77	\N	49	99	2024-11-14	2
130	\N	0	59	2024-06-22	3
78	\N	50	99	2024-11-21	2
79	\N	49	99	2024-11-28	2
80	\N	50	99	2024-12-05	2
81	\N	49	99	2024-09-20	2
82	\N	50	99	2024-09-27	2
83	\N	49	99	2024-10-04	2
150	\N	0	60	2024-07-07	3
200	\N	0	60	2024-06-22	4
151	\N	0	60	2024-07-14	3
152	\N	0	60	2024-07-21	3
153	\N	0	60	2024-07-28	3
201	\N	0	60	2024-06-29	4
154	\N	0	60	2024-08-04	3
155	\N	0	60	2024-08-11	3
257	\N	50	100	2024-07-20	5
156	\N	0	60	2024-08-18	3
202	\N	0	60	2024-07-06	4
157	\N	0	60	2024-08-25	3
158	\N	0	60	2024-09-01	3
159	\N	0	60	2024-09-08	3
203	\N	0	60	2024-07-13	4
160	\N	0	60	2024-09-15	3
161	\N	0	60	2024-09-22	3
162	\N	0	60	2024-09-29	3
204	\N	0	60	2024-07-20	4
258	\N	50	100	2024-07-27	5
205	\N	0	60	2024-07-27	4
206	\N	0	60	2024-08-03	4
207	\N	0	60	2024-08-10	4
259	\N	50	100	2024-08-03	5
208	\N	0	60	2024-08-17	4
209	\N	0	60	2024-08-24	4
210	\N	0	60	2024-08-31	4
260	\N	50	100	2024-08-10	5
211	\N	0	60	2024-09-07	4
212	\N	0	60	2024-09-14	4
213	\N	0	60	2024-09-21	4
261	\N	50	100	2024-08-17	5
214	\N	0	60	2024-09-28	4
215	\N	0	60	2024-06-02	4
216	\N	0	60	2024-06-09	4
262	\N	50	100	2024-08-24	5
217	\N	0	60	2024-06-16	4
218	\N	0	60	2024-06-23	4
219	\N	0	60	2024-06-30	4
263	\N	50	100	2024-08-31	5
220	\N	0	60	2024-07-07	4
221	\N	0	60	2024-07-14	4
222	\N	0	60	2024-07-21	4
264	\N	50	100	2024-09-07	5
223	\N	0	60	2024-07-28	4
224	\N	0	60	2024-08-04	4
225	\N	0	60	2024-08-11	4
265	\N	50	100	2024-09-14	5
226	\N	0	60	2024-08-18	4
227	\N	0	60	2024-08-25	4
228	\N	0	60	2024-09-01	4
266	\N	50	100	2024-09-21	5
229	\N	0	60	2024-09-08	4
230	\N	0	60	2024-09-15	4
231	\N	0	60	2024-09-22	4
267	\N	50	100	2024-09-28	5
232	\N	0	60	2024-09-29	4
268	\N	50	100	2024-06-02	5
269	\N	50	100	2024-06-09	5
270	\N	50	100	2024-06-16	5
271	\N	50	100	2024-06-23	5
272	\N	50	100	2024-06-30	5
273	\N	50	100	2024-07-07	5
274	\N	50	100	2024-07-14	5
275	\N	50	100	2024-07-21	5
276	\N	50	100	2024-07-28	5
277	\N	50	100	2024-08-04	5
278	\N	50	100	2024-08-11	5
279	\N	50	100	2024-08-18	5
280	\N	50	100	2024-08-25	5
281	\N	50	100	2024-09-01	5
282	\N	50	100	2024-09-08	5
283	\N	50	100	2024-09-15	5
284	\N	50	100	2024-09-22	5
285	\N	50	100	2024-09-29	5
286	\N	50	100	2024-06-04	6
287	\N	50	100	2024-06-11	6
288	\N	50	100	2024-06-18	6
289	\N	50	100	2024-06-25	6
290	\N	50	100	2024-07-02	6
291	\N	50	100	2024-07-09	6
292	\N	50	100	2024-07-16	6
293	\N	50	100	2024-07-23	6
294	\N	50	100	2024-07-30	6
295	\N	50	100	2024-08-06	6
296	\N	50	100	2024-08-13	6
297	\N	50	100	2024-08-20	6
298	\N	50	100	2024-08-27	6
299	\N	50	100	2024-09-03	6
300	\N	50	100	2024-09-10	6
301	\N	50	100	2024-09-17	6
302	\N	50	100	2024-09-24	6
303	\N	50	100	2024-06-01	6
304	\N	50	100	2024-06-08	6
305	\N	50	100	2024-06-15	6
306	\N	50	100	2024-06-22	6
307	\N	50	100	2024-06-29	6
308	\N	50	100	2024-07-06	6
309	\N	50	100	2024-07-13	6
310	\N	50	100	2024-07-20	6
311	\N	50	100	2024-07-27	6
312	\N	50	100	2024-08-03	6
313	\N	50	100	2024-08-10	6
314	\N	50	100	2024-08-17	6
315	\N	50	100	2024-08-24	6
316	\N	50	100	2024-08-31	6
317	\N	50	100	2024-09-07	6
318	\N	50	100	2024-09-14	6
319	\N	50	100	2024-09-21	6
320	\N	50	100	2024-09-28	6
321	\N	50	100	2024-06-02	6
322	\N	50	100	2024-06-09	6
323	\N	50	100	2024-06-16	6
324	\N	50	100	2024-06-23	6
325	\N	50	100	2024-06-30	6
326	\N	50	100	2024-07-07	6
327	\N	50	100	2024-07-14	6
328	\N	50	100	2024-07-21	6
329	\N	50	100	2024-07-28	6
330	\N	50	100	2024-08-04	6
331	\N	50	100	2024-08-11	6
332	\N	50	100	2024-08-18	6
333	\N	50	100	2024-08-25	6
334	\N	50	100	2024-09-01	6
335	\N	50	100	2024-09-08	6
336	\N	50	100	2024-09-15	6
337	\N	50	100	2024-09-22	6
338	\N	50	100	2024-09-29	6
339	\N	50	100	2024-06-04	7
340	\N	50	100	2024-06-11	7
341	\N	50	100	2024-06-18	7
342	\N	50	100	2024-06-25	7
343	\N	50	100	2024-07-02	7
344	\N	50	100	2024-07-09	7
345	\N	50	100	2024-07-16	7
346	\N	50	100	2024-07-23	7
347	\N	50	100	2024-07-30	7
348	\N	50	100	2024-08-06	7
349	\N	50	100	2024-08-13	7
350	\N	50	100	2024-08-20	7
351	\N	50	100	2024-08-27	7
352	\N	50	100	2024-09-03	7
353	\N	50	100	2024-09-10	7
354	\N	50	100	2024-09-17	7
355	\N	50	100	2024-09-24	7
356	\N	50	100	2024-06-01	7
357	\N	50	100	2024-06-08	7
358	\N	50	100	2024-06-15	7
359	\N	50	100	2024-06-22	7
360	\N	50	100	2024-06-29	7
361	\N	50	100	2024-07-06	7
362	\N	50	100	2024-07-13	7
363	\N	50	100	2024-07-20	7
364	\N	50	100	2024-07-27	7
365	\N	50	100	2024-08-03	7
366	\N	50	100	2024-08-10	7
367	\N	50	100	2024-08-17	7
368	\N	50	100	2024-08-24	7
369	\N	50	100	2024-08-31	7
370	\N	50	100	2024-09-07	7
371	\N	50	100	2024-09-14	7
372	\N	50	100	2024-09-21	7
373	\N	50	100	2024-09-28	7
374	\N	50	100	2024-06-02	7
375	\N	50	100	2024-06-09	7
376	\N	50	100	2024-06-16	7
377	\N	50	100	2024-06-23	7
378	\N	50	100	2024-06-30	7
379	\N	50	100	2024-07-07	7
380	\N	50	100	2024-07-14	7
381	\N	50	100	2024-07-21	7
382	\N	50	100	2024-07-28	7
383	\N	50	100	2024-08-04	7
384	\N	50	100	2024-08-11	7
385	\N	50	100	2024-08-18	7
386	\N	50	100	2024-08-25	7
387	\N	50	100	2024-09-01	7
388	\N	50	100	2024-09-08	7
389	\N	50	100	2024-09-15	7
390	\N	50	100	2024-09-22	7
391	\N	50	100	2024-09-29	7
392	\N	50	100	2024-06-04	8
393	\N	50	100	2024-06-11	8
394	\N	50	100	2024-06-18	8
395	\N	50	100	2024-06-25	8
396	\N	50	100	2024-07-02	8
397	\N	50	100	2024-07-09	8
398	\N	50	100	2024-07-16	8
399	\N	50	100	2024-07-23	8
400	\N	50	100	2024-07-30	8
401	\N	50	100	2024-08-06	8
402	\N	50	100	2024-08-13	8
403	\N	50	100	2024-08-20	8
404	\N	50	100	2024-08-27	8
405	\N	50	100	2024-09-03	8
406	\N	50	100	2024-09-10	8
407	\N	50	100	2024-09-17	8
408	\N	50	100	2024-09-24	8
409	\N	50	100	2024-06-01	8
410	\N	50	100	2024-06-08	8
411	\N	50	100	2024-06-15	8
412	\N	50	100	2024-06-22	8
413	\N	50	100	2024-06-29	8
414	\N	50	100	2024-07-06	8
415	\N	50	100	2024-07-13	8
416	\N	50	100	2024-07-20	8
417	\N	50	100	2024-07-27	8
418	\N	50	100	2024-08-03	8
419	\N	50	100	2024-08-10	8
420	\N	50	100	2024-08-17	8
421	\N	50	100	2024-08-24	8
422	\N	50	100	2024-08-31	8
423	\N	50	100	2024-09-07	8
424	\N	50	100	2024-09-14	8
425	\N	50	100	2024-09-21	8
426	\N	50	100	2024-09-28	8
427	\N	50	100	2024-06-02	8
428	\N	50	100	2024-06-09	8
429	\N	50	100	2024-06-16	8
430	\N	50	100	2024-06-23	8
431	\N	50	100	2024-06-30	8
432	\N	50	100	2024-07-07	8
433	\N	50	100	2024-07-14	8
434	\N	50	100	2024-07-21	8
435	\N	50	100	2024-07-28	8
436	\N	50	100	2024-08-04	8
437	\N	50	100	2024-08-11	8
438	\N	50	100	2024-08-18	8
439	\N	50	100	2024-08-25	8
440	\N	50	100	2024-09-01	8
441	\N	50	100	2024-09-08	8
442	\N	50	100	2024-09-15	8
443	\N	50	100	2024-09-22	8
444	\N	50	100	2024-09-29	8
445	\N	0	50	2023-12-18	9
446	\N	0	50	2023-12-25	9
447	\N	0	50	2024-01-01	9
448	\N	0	50	2024-01-08	9
449	\N	0	50	2024-01-15	9
450	\N	0	50	2024-01-22	9
451	\N	0	50	2024-01-29	9
452	\N	0	50	2024-02-05	9
453	\N	0	50	2024-02-12	9
454	\N	0	50	2024-02-19	9
455	\N	0	50	2024-02-26	9
456	\N	0	75	2023-11-20	10
457	\N	0	75	2023-11-27	10
458	\N	0	75	2023-12-04	10
459	\N	0	75	2023-12-11	10
460	\N	0	75	2023-12-18	10
461	\N	0	75	2023-12-25	10
462	\N	0	75	2024-01-01	10
463	\N	0	75	2024-01-08	10
464	\N	0	75	2024-01-15	10
465	\N	0	75	2024-01-22	10
466	\N	0	75	2024-01-29	10
467	\N	0	75	2023-11-20	11
468	\N	0	75	2023-11-27	11
469	\N	0	75	2023-12-04	11
470	\N	0	75	2023-12-11	11
471	\N	0	75	2023-12-18	11
500	canc	0	0	2024-10-21	15
472	\N	0	75	2023-12-25	11
473	\N	0	75	2024-01-01	11
474	\N	0	75	2024-01-08	11
475	\N	0	75	2024-01-15	11
476	\N	0	75	2024-01-22	11
477	\N	0	75	2024-01-29	11
478	\N	50	150	2024-05-18	13
479	\N	50	150	2024-05-25	13
480	\N	50	150	2024-06-01	13
481	\N	50	150	2024-06-08	13
482	\N	50	150	2024-06-15	13
483	\N	50	150	2024-06-22	13
484	\N	50	150	2024-06-29	13
485	\N	50	150	2024-07-06	13
486	\N	50	150	2024-07-13	13
487	\N	50	150	2024-07-20	13
488	\N	50	150	2024-07-27	13
489	\N	50	150	2024-08-03	13
490	\N	50	150	2024-08-10	13
491	\N	50	150	2024-08-17	13
492	\N	50	150	2024-08-24	13
493	\N	50	150	2024-08-31	13
494	\N	50	150	2024-09-07	13
495	\N	50	150	2024-09-14	13
496	\N	50	100	2024-09-23	15
497	\N	50	100	2024-09-30	15
498	\N	50	100	2024-10-07	15
499	\N	50	100	2024-10-14	15
501	\N	50	100	2024-10-28	15
502	\N	50	100	2024-11-04	15
503	\N	50	100	2024-11-11	15
504	\N	50	100	2024-11-18	15
505	\N	50	100	2024-11-25	15
506	\N	50	100	2024-12-02	15
507	\N	50	100	2024-09-24	15
508	\N	50	100	2024-10-01	15
509	\N	50	100	2024-10-08	15
510	\N	50	100	2024-10-15	15
511	\N	50	100	2024-10-22	15
512	\N	50	100	2024-10-29	15
513	\N	50	100	2024-11-05	15
514	\N	50	100	2024-11-12	15
515	\N	50	100	2024-11-19	15
516	\N	50	100	2024-11-26	15
517	\N	50	100	2024-12-03	15
518	\N	50	100	2024-09-25	15
519	\N	50	100	2024-10-02	15
520	\N	50	100	2024-10-09	15
521	\N	50	100	2024-10-16	15
522	\N	50	100	2024-10-23	15
523	\N	50	100	2024-10-30	15
524	\N	50	100	2024-11-06	15
525	\N	50	100	2024-11-13	15
526	\N	50	100	2024-11-20	15
527	\N	50	100	2024-11-27	15
528	\N	50	100	2024-12-04	15
529	\N	50	100	2024-09-26	15
530	\N	50	100	2024-10-03	15
531	\N	50	100	2024-10-10	15
532	\N	50	100	2024-10-17	15
533	\N	50	100	2024-10-24	15
534	\N	50	100	2024-10-31	15
535	\N	50	100	2024-11-07	15
536	\N	50	100	2024-11-14	15
537	\N	50	100	2024-11-21	15
538	\N	50	100	2024-11-28	15
539	\N	50	100	2024-12-05	15
540	\N	50	100	2024-09-20	15
541	\N	50	100	2024-09-27	15
542	\N	50	100	2024-10-04	15
543	\N	50	100	2024-10-11	15
544	\N	50	100	2024-10-18	15
545	\N	50	100	2024-10-25	15
546	\N	50	100	2024-11-01	15
547	\N	50	100	2024-11-08	15
548	\N	50	100	2024-11-15	15
549	\N	50	100	2024-11-22	15
550	\N	50	100	2024-11-29	15
551	\N	50	100	2024-12-06	15
552	\N	0	50	2024-03-25	16
553	\N	0	50	2024-04-01	16
554	\N	0	50	2024-04-08	16
555	\N	0	50	2024-04-15	16
556	\N	0	50	2024-04-22	16
557	\N	0	50	2024-04-29	16
558	\N	0	50	2024-05-06	16
559	\N	0	50	2024-05-13	16
560	\N	0	50	2024-05-20	16
561	\N	0	50	2024-03-27	16
562	\N	0	50	2024-04-03	16
563	\N	0	50	2024-04-10	16
564	\N	0	50	2024-04-17	16
565	\N	0	50	2024-04-24	16
566	\N	0	50	2024-05-01	16
567	\N	0	50	2024-05-08	16
568	\N	0	50	2024-05-15	16
569	\N	0	50	2024-03-22	16
570	\N	0	50	2024-03-29	16
571	\N	0	50	2024-04-05	16
572	\N	0	50	2024-04-12	16
573	\N	0	50	2024-04-19	16
574	\N	0	50	2024-04-26	16
575	\N	0	50	2024-05-03	16
576	\N	0	50	2024-05-10	16
577	\N	0	50	2024-05-17	16
578	\N	50	150	2024-06-01	17
579	\N	50	150	2024-06-08	17
580	\N	50	150	2024-06-15	17
581	\N	50	150	2024-06-22	17
582	\N	50	150	2024-06-29	17
583	\N	50	150	2024-07-06	17
584	\N	50	150	2024-07-13	17
585	\N	50	150	2024-07-20	17
586	\N	50	150	2024-07-27	17
587	\N	50	150	2024-08-03	17
588	\N	50	150	2024-08-10	17
589	\N	50	150	2024-08-17	17
590	\N	50	150	2024-08-24	17
591	\N	50	150	2024-08-31	17
592	\N	50	150	2024-09-07	17
593	\N	50	150	2024-09-14	17
594	\N	50	150	2024-09-21	17
595	\N	50	150	2024-09-28	17
596	\N	50	150	2024-06-02	17
597	\N	50	150	2024-06-09	17
598	\N	50	150	2024-06-16	17
599	\N	50	150	2024-06-23	17
600	\N	50	150	2024-06-30	17
601	\N	50	150	2024-07-07	17
602	\N	50	150	2024-07-14	17
603	\N	50	150	2024-07-21	17
604	\N	50	150	2024-07-28	17
605	\N	50	150	2024-08-04	17
606	\N	50	150	2024-08-11	17
607	\N	50	150	2024-08-18	17
608	\N	50	150	2024-08-25	17
609	\N	50	150	2024-09-01	17
610	\N	50	150	2024-09-08	17
611	\N	50	150	2024-09-15	17
612	\N	50	150	2024-09-22	17
613	\N	50	150	2024-09-29	17
614	\N	0	50	2024-02-05	18
615	\N	0	50	2024-02-12	18
616	\N	0	50	2024-02-19	18
617	\N	0	50	2024-02-26	18
618	\N	0	50	2024-03-04	18
619	\N	0	50	2024-03-11	18
620	\N	0	50	2024-03-18	18
621	\N	0	50	2024-03-25	18
622	\N	0	50	2024-04-01	18
623	\N	0	50	2024-04-08	18
624	\N	0	50	2024-04-15	18
625	\N	0	50	2024-04-22	18
626	\N	0	50	2024-04-29	18
627	\N	0	50	2024-05-06	18
628	\N	0	50	2024-05-13	18
629	\N	0	50	2024-05-20	18
630	\N	0	50	2024-05-27	18
631	\N	0	50	2024-06-03	18
632	\N	0	50	2024-06-10	18
633	\N	0	50	2024-06-17	18
634	\N	0	50	2024-06-24	18
635	\N	0	50	2024-07-01	18
636	\N	0	50	2024-07-08	18
637	\N	0	50	2024-07-15	18
638	\N	0	50	2024-07-22	18
639	\N	0	50	2024-07-29	18
640	\N	0	50	2024-08-05	18
641	\N	0	50	2024-08-12	18
642	\N	0	50	2024-08-19	18
643	\N	0	50	2024-08-26	18
644	\N	0	50	2024-09-02	18
645	\N	0	50	2024-09-09	18
646	\N	0	50	2024-09-16	18
647	\N	0	50	2024-09-23	18
648	\N	0	50	2024-09-30	18
649	\N	0	50	2024-01-31	18
650	\N	0	50	2024-02-07	18
651	\N	0	50	2024-02-14	18
652	\N	0	50	2024-02-21	18
653	\N	0	50	2024-02-28	18
654	\N	0	50	2024-03-06	18
655	\N	0	50	2024-03-13	18
656	\N	0	50	2024-03-20	18
657	\N	0	50	2024-03-27	18
658	\N	0	50	2024-04-03	18
659	\N	0	50	2024-04-10	18
660	\N	0	50	2024-04-17	18
661	\N	0	50	2024-04-24	18
662	\N	0	50	2024-05-01	18
663	\N	0	50	2024-05-08	18
664	\N	0	50	2024-05-15	18
665	\N	0	50	2024-05-22	18
666	\N	0	50	2024-05-29	18
667	\N	0	50	2024-06-05	18
668	\N	0	50	2024-06-12	18
669	\N	0	50	2024-06-19	18
670	\N	0	50	2024-06-26	18
671	\N	0	50	2024-07-03	18
672	\N	0	50	2024-07-10	18
673	\N	0	50	2024-07-17	18
674	\N	0	50	2024-07-24	18
675	\N	0	50	2024-07-31	18
676	\N	0	50	2024-08-07	18
677	\N	0	50	2024-08-14	18
678	\N	0	50	2024-08-21	18
679	\N	0	50	2024-08-28	18
680	\N	0	50	2024-09-04	18
681	\N	0	50	2024-09-11	18
682	\N	0	50	2024-09-18	18
683	\N	0	50	2024-09-25	18
684	\N	0	50	2024-02-01	18
685	\N	0	50	2024-02-08	18
686	\N	0	50	2024-02-15	18
687	\N	0	50	2024-02-22	18
688	\N	0	50	2024-02-29	18
689	\N	0	50	2024-03-07	18
690	\N	0	50	2024-03-14	18
691	\N	0	50	2024-03-21	18
692	\N	0	50	2024-03-28	18
693	\N	0	50	2024-04-04	18
694	\N	0	50	2024-04-11	18
695	\N	0	50	2024-04-18	18
696	\N	0	50	2024-04-25	18
697	\N	0	50	2024-05-02	18
698	\N	0	50	2024-05-09	18
699	\N	0	50	2024-05-16	18
700	\N	0	50	2024-05-23	18
701	\N	0	50	2024-05-30	18
702	\N	0	50	2024-06-06	18
703	\N	0	50	2024-06-13	18
704	\N	0	50	2024-06-20	18
705	\N	0	50	2024-06-27	18
706	\N	0	50	2024-07-04	18
707	\N	0	50	2024-07-11	18
708	\N	0	50	2024-07-18	18
709	\N	0	50	2024-07-25	18
710	\N	0	50	2024-08-01	18
711	\N	0	50	2024-08-08	18
712	\N	0	50	2024-08-15	18
713	\N	0	50	2024-08-22	18
714	\N	0	50	2024-08-29	18
715	\N	0	50	2024-09-05	18
716	\N	0	50	2024-09-12	18
717	\N	0	50	2024-09-19	18
718	\N	0	50	2024-09-26	18
719	\N	0	50	2024-02-03	18
720	\N	0	50	2024-02-10	18
721	\N	0	50	2024-02-17	18
722	\N	0	50	2024-02-24	18
723	\N	0	50	2024-03-02	18
724	\N	0	50	2024-03-09	18
725	\N	0	50	2024-03-16	18
726	\N	0	50	2024-03-23	18
727	\N	0	50	2024-03-30	18
728	\N	0	50	2024-04-06	18
729	\N	0	50	2024-04-13	18
730	\N	0	50	2024-04-20	18
731	\N	0	50	2024-04-27	18
732	\N	0	50	2024-05-04	18
733	\N	0	50	2024-05-11	18
734	\N	0	50	2024-05-18	18
735	\N	0	50	2024-05-25	18
736	\N	0	50	2024-06-01	18
737	\N	0	50	2024-06-08	18
738	\N	0	50	2024-06-15	18
739	\N	0	50	2024-06-22	18
740	\N	0	50	2024-06-29	18
741	\N	0	50	2024-07-06	18
742	\N	0	50	2024-07-13	18
743	\N	0	50	2024-07-20	18
744	\N	0	50	2024-07-27	18
745	\N	0	50	2024-08-03	18
746	\N	0	50	2024-08-10	18
747	\N	0	50	2024-08-17	18
748	\N	0	50	2024-08-24	18
749	\N	0	50	2024-08-31	18
750	\N	0	50	2024-09-07	18
751	\N	0	50	2024-09-14	18
752	\N	0	50	2024-09-21	18
753	\N	0	50	2024-09-28	18
754	\N	0	50	2024-02-04	18
755	\N	0	50	2024-02-11	18
756	\N	0	50	2024-02-18	18
757	\N	0	50	2024-02-25	18
758	\N	0	50	2024-03-03	18
759	\N	0	50	2024-03-10	18
760	\N	0	50	2024-03-17	18
761	\N	0	50	2024-03-24	18
762	\N	0	50	2024-03-31	18
763	\N	0	50	2024-04-07	18
764	\N	0	50	2024-04-14	18
765	\N	0	50	2024-04-21	18
766	\N	0	50	2024-04-28	18
767	\N	0	50	2024-05-05	18
768	\N	0	50	2024-05-12	18
769	\N	0	50	2024-05-19	18
770	\N	0	50	2024-05-26	18
771	\N	0	50	2024-06-02	18
772	\N	0	50	2024-06-09	18
773	\N	0	50	2024-06-16	18
774	\N	0	50	2024-06-23	18
775	\N	0	50	2024-06-30	18
776	\N	0	50	2024-07-07	18
777	\N	0	50	2024-07-14	18
778	\N	0	50	2024-07-21	18
779	\N	0	50	2024-07-28	18
780	\N	0	50	2024-08-04	18
781	\N	0	50	2024-08-11	18
782	\N	0	50	2024-08-18	18
783	\N	0	50	2024-08-25	18
784	\N	0	50	2024-09-01	18
785	\N	0	50	2024-09-08	18
786	\N	0	50	2024-09-15	18
787	\N	0	50	2024-09-22	18
788	\N	0	50	2024-09-29	18
789	\N	50	150	2024-02-05	19
790	\N	50	150	2024-02-12	19
791	\N	50	150	2024-02-19	19
792	\N	50	150	2024-02-26	19
793	\N	50	150	2024-03-04	19
794	\N	50	150	2024-03-11	19
795	\N	50	150	2024-03-18	19
796	\N	50	150	2024-03-25	19
797	\N	50	150	2024-04-01	19
798	\N	50	150	2024-04-08	19
799	\N	50	150	2024-04-15	19
800	\N	50	150	2024-04-22	19
801	\N	50	150	2024-04-29	19
802	\N	50	150	2024-05-06	19
803	\N	50	150	2024-05-13	19
804	\N	50	150	2024-05-20	19
805	\N	50	150	2024-05-27	19
806	\N	50	150	2024-06-03	19
807	\N	50	150	2024-06-10	19
808	\N	50	150	2024-06-17	19
809	\N	50	150	2024-06-24	19
810	\N	50	150	2024-07-01	19
811	\N	50	150	2024-07-08	19
812	\N	50	150	2024-07-15	19
813	\N	50	150	2024-07-22	19
814	\N	50	150	2024-07-29	19
815	\N	50	150	2024-08-05	19
816	\N	50	150	2024-08-12	19
817	\N	50	150	2024-08-19	19
818	\N	50	150	2024-08-26	19
819	\N	50	150	2024-09-02	19
820	\N	50	150	2024-09-09	19
821	\N	50	150	2024-09-16	19
822	\N	50	150	2024-09-23	19
823	\N	50	150	2024-09-30	19
824	\N	50	150	2024-01-31	19
825	\N	50	150	2024-02-07	19
826	\N	50	150	2024-02-14	19
827	\N	50	150	2024-02-21	19
828	\N	50	150	2024-02-28	19
829	\N	50	150	2024-03-06	19
830	\N	50	150	2024-03-13	19
831	\N	50	150	2024-03-20	19
832	\N	50	150	2024-03-27	19
833	\N	50	150	2024-04-03	19
834	\N	50	150	2024-04-10	19
835	\N	50	150	2024-04-17	19
836	\N	50	150	2024-04-24	19
837	\N	50	150	2024-05-01	19
838	\N	50	150	2024-05-08	19
839	\N	50	150	2024-05-15	19
840	\N	50	150	2024-05-22	19
841	\N	50	150	2024-05-29	19
842	\N	50	150	2024-06-05	19
843	\N	50	150	2024-06-12	19
844	\N	50	150	2024-06-19	19
845	\N	50	150	2024-06-26	19
846	\N	50	150	2024-07-03	19
847	\N	50	150	2024-07-10	19
848	\N	50	150	2024-07-17	19
849	\N	50	150	2024-07-24	19
850	\N	50	150	2024-07-31	19
851	\N	50	150	2024-08-07	19
852	\N	50	150	2024-08-14	19
853	\N	50	150	2024-08-21	19
854	\N	50	150	2024-08-28	19
855	\N	50	150	2024-09-04	19
856	\N	50	150	2024-09-11	19
857	\N	50	150	2024-09-18	19
858	\N	50	150	2024-09-25	19
859	\N	50	150	2024-02-01	19
860	\N	50	150	2024-02-08	19
861	\N	50	150	2024-02-15	19
862	\N	50	150	2024-02-22	19
863	\N	50	150	2024-02-29	19
864	\N	50	150	2024-03-07	19
865	\N	50	150	2024-03-14	19
866	\N	50	150	2024-03-21	19
867	\N	50	150	2024-03-28	19
868	\N	50	150	2024-04-04	19
869	\N	50	150	2024-04-11	19
870	\N	50	150	2024-04-18	19
871	\N	50	150	2024-04-25	19
872	\N	50	150	2024-05-02	19
873	\N	50	150	2024-05-09	19
874	\N	50	150	2024-05-16	19
875	\N	50	150	2024-05-23	19
876	\N	50	150	2024-05-30	19
877	\N	50	150	2024-06-06	19
878	\N	50	150	2024-06-13	19
879	\N	50	150	2024-06-20	19
880	\N	50	150	2024-06-27	19
881	\N	50	150	2024-07-04	19
882	\N	50	150	2024-07-11	19
883	\N	50	150	2024-07-18	19
884	\N	50	150	2024-07-25	19
885	\N	50	150	2024-08-01	19
886	\N	50	150	2024-08-08	19
887	\N	50	150	2024-08-15	19
888	\N	50	150	2024-08-22	19
889	\N	50	150	2024-08-29	19
890	\N	50	150	2024-09-05	19
891	\N	50	150	2024-09-12	19
892	\N	50	150	2024-09-19	19
893	\N	50	150	2024-09-26	19
894	\N	50	150	2024-02-03	19
895	\N	50	150	2024-02-10	19
896	\N	50	150	2024-02-17	19
897	\N	50	150	2024-02-24	19
898	\N	50	150	2024-03-02	19
899	\N	50	150	2024-03-09	19
900	\N	50	150	2024-03-16	19
901	\N	50	150	2024-03-23	19
902	\N	50	150	2024-03-30	19
903	\N	50	150	2024-04-06	19
904	\N	50	150	2024-04-13	19
905	\N	50	150	2024-04-20	19
906	\N	50	150	2024-04-27	19
907	\N	50	150	2024-05-04	19
908	\N	50	150	2024-05-11	19
909	\N	50	150	2024-05-18	19
910	\N	50	150	2024-05-25	19
911	\N	50	150	2024-06-01	19
912	\N	50	150	2024-06-08	19
913	\N	50	150	2024-06-15	19
914	\N	50	150	2024-06-22	19
915	\N	50	150	2024-06-29	19
916	\N	50	150	2024-07-06	19
917	\N	50	150	2024-07-13	19
918	\N	50	150	2024-07-20	19
919	\N	50	150	2024-07-27	19
920	\N	50	150	2024-08-03	19
921	\N	50	150	2024-08-10	19
11	\N	50	99	2024-08-10	1
922	\N	50	150	2024-08-17	19
923	\N	50	150	2024-08-24	19
12	\N	49	99	2024-08-17	1
924	\N	50	150	2024-08-31	19
925	\N	50	150	2024-09-07	19
13	\N	50	99	2024-08-24	1
926	\N	50	150	2024-09-14	19
927	\N	50	150	2024-09-21	19
14	\N	49	99	2024-08-31	1
928	\N	50	150	2024-09-28	19
929	\N	50	150	2024-02-04	19
15	\N	50	99	2024-09-07	1
930	\N	50	150	2024-02-11	19
931	\N	50	150	2024-02-18	19
16	\N	49	99	2024-09-14	1
932	\N	50	150	2024-02-25	19
933	\N	50	150	2024-03-03	19
17	\N	50	99	2024-09-21	1
934	\N	50	150	2024-03-10	19
935	\N	50	150	2024-03-17	19
18	\N	49	99	2024-09-28	1
936	\N	50	150	2024-03-24	19
937	\N	50	150	2024-03-31	19
19	\N	50	99	2024-06-02	1
938	\N	50	150	2024-04-07	19
939	\N	50	150	2024-04-14	19
20	30'	49	99	2024-06-09	1
940	\N	50	150	2024-04-21	19
941	\N	50	150	2024-04-28	19
21	\N	50	99	2024-06-16	1
942	\N	50	150	2024-05-05	19
943	\N	50	150	2024-05-12	19
22	\N	49	99	2024-06-23	1
944	\N	50	150	2024-05-19	19
945	\N	50	150	2024-05-26	19
23	\N	50	99	2024-06-30	1
946	\N	50	150	2024-06-02	19
947	\N	50	150	2024-06-09	19
24	\N	49	99	2024-07-07	1
948	\N	50	150	2024-06-16	19
949	\N	50	150	2024-06-23	19
25	\N	50	99	2024-07-14	1
950	\N	50	150	2024-06-30	19
951	\N	50	150	2024-07-07	19
26	\N	49	99	2024-07-21	1
952	\N	50	150	2024-07-14	19
953	\N	50	150	2024-07-21	19
27	\N	50	99	2024-07-28	1
954	\N	50	150	2024-07-28	19
955	\N	50	150	2024-08-04	19
28	\N	49	99	2024-08-04	1
956	\N	50	150	2024-08-11	19
957	\N	50	150	2024-08-18	19
29	\N	50	99	2024-08-11	1
958	\N	50	150	2024-08-25	19
959	\N	50	150	2024-09-01	19
30	\N	49	99	2024-08-18	1
960	\N	50	150	2024-09-08	19
961	\N	50	150	2024-09-15	19
31	\N	50	99	2024-08-25	1
962	\N	50	150	2024-09-22	19
963	\N	50	150	2024-09-29	19
32	10'	49	99	2024-09-01	1
37	\N	50	99	2024-09-23	2
38	\N	49	99	2024-09-30	2
39	\N	50	99	2024-10-07	2
40	\N	49	99	2024-10-14	2
41	\N	50	99	2024-10-21	2
42	\N	49	99	2024-10-28	2
43	\N	50	99	2024-11-04	2
44	\N	49	99	2024-11-11	2
45	\N	50	99	2024-11-18	2
46	\N	49	99	2024-11-25	2
47	\N	50	99	2024-12-02	2
48	\N	49	99	2024-09-24	2
49	\N	50	99	2024-10-01	2
50	\N	49	99	2024-10-08	2
84	\N	50	99	2024-10-11	2
85	\N	49	99	2024-10-18	2
86	\N	50	99	2024-10-25	2
87	\N	49	99	2024-11-01	2
88	\N	50	99	2024-11-08	2
89	43'	49	99	2024-11-15	2
90	\N	50	99	2024-11-22	2
91	\N	49	99	2024-11-29	2
92	\N	50	99	2024-12-06	2
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

COPY public.navigazione (idtratta, codnatante) FROM stdin;
1	13
2	2
3	11
4	12
5	13
6	13
7	13
8	13
9	1
10	10
11	10
12	2
13	6
14	5
15	7
16	5
17	6
18	4
19	6
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
123	Kurt	Cobain	1967-02-20
124	Mick	Jagger	1943-07-26
125	Freddie	Mercury	1946-09-05
126	David	Bowie	1947-01-08
127	Dave	Gahan	1962-05-09
128	Giovanni	Di Meo	2007-07-01
\.


--
-- Data for Name: prenotazione; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.prenotazione (idpasseggero, sovrapprezzoprenotazione, sovrapprezzobagagli, idprenotazione, peso_bagaglio, auto, idcorsa) FROM stdin;
29	3	10	57	18.5	f	93
23	3	0	1	4.23	f	2
110	3	10	2	15.23	f	2
111	3	0	3	1.23	f	2
11	3	10	4	8.3	f	2
13	3	10	5	8.3	f	2
13	3	0	6	5	f	2
15	3	0	7	5	f	2
18	3	0	8	5	f	2
10	3	0	9	5	f	2
20	3	0	10	5	f	2
128	3	0	11	5	f	2
127	3	0	12	5	f	2
126	3	0	13	5	f	2
122	3	0	14	5	f	2
121	3	0	15	5	f	2
120	3	0	16	5	f	2
110	3	0	17	5	f	2
83	3	0	18	5	f	2
75	3	0	19	5	f	2
79	3	0	20	5	f	2
79	3	0	21	5	f	2
25	3	10	22	7	f	2
25	3	10	23	7	f	2
26	3	10	24	7	f	2
26	3	10	25	9	f	2
15	3	10	26	10	f	2
15	3	0	27	3	f	2
17	3	0	28	3	f	2
17	3	0	29	0	f	2
19	3	0	30	0	f	2
20	3	0	31	0	f	2
20	3	0	32	0	f	2
40	3	0	33	0	f	2
41	3	0	34	0	f	2
41	3	10	35	8	f	2
42	3	10	36	8	f	2
50	3	10	37	8	f	2
58	3	10	38	8	f	2
58	3	10	39	11.5	f	2
68	3	10	40	18.5	f	2
64	3	10	41	18.5	f	2
63	3	10	42	18.5	f	2
73	3	10	43	18.5	f	2
83	3	10	44	18.5	f	2
86	3	10	45	18.5	f	2
89	3	10	46	18.5	f	2
99	3	10	47	18.5	f	2
109	3	10	48	18.5	f	2
119	3	10	49	18.5	f	2
29	3	10	55	18.5	f	3
51	3	0	402	3.5	t	51
53	3	0	404	4	t	53
55	3	0	406	4.5	t	55
57	3	0	408	5	t	57
59	3	10	410	5.5	t	59
61	3	10	412	6	t	61
63	3	10	414	6.5	t	63
65	3	10	416	7	t	65
67	3	10	418	7.5	t	67
69	3	10	420	8	t	69
71	3	10	422	8.5	t	71
73	3	10	424	9	t	73
75	3	10	426	9.5	t	75
77	3	10	428	10	t	77
79	3	10	430	10.5	t	79
81	3	10	432	11	t	81
83	3	10	434	11.5	t	83
85	3	10	436	12	t	85
87	3	10	438	12.5	t	87
89	3	10	440	13	t	89
91	3	10	442	13.5	t	91
52	3	10	403	36	f	52
54	3	10	405	36.5	f	54
56	3	10	407	37	f	56
58	3	10	409	37.5	f	58
60	3	10	411	38	f	60
62	3	10	413	38.5	f	62
64	3	10	415	39	f	64
66	3	10	417	39.5	f	66
68	3	10	419	40	f	68
70	3	10	421	40.5	f	70
72	3	10	423	41	f	72
74	3	10	425	41.5	f	74
76	3	10	427	42	f	76
78	3	10	429	42.5	f	78
80	3	10	431	43	f	80
82	3	10	433	43.5	f	82
84	3	10	435	44	f	84
86	3	10	437	44.5	f	86
88	3	10	439	45	f	88
90	3	10	441	45.5	f	90
92	3	10	443	46	f	92
93	3	10	444	14	f	93
94	3	10	445	46.5	f	94
95	3	10	446	14.5	f	95
96	3	10	447	47	f	96
97	3	10	448	15	f	97
98	3	10	449	47.5	f	98
99	3	10	450	15.5	f	99
100	3	10	451	48	f	100
101	3	10	482	16	f	101
102	3	10	483	48.5	f	102
103	3	10	484	16.5	f	103
104	3	10	485	49	f	104
105	3	10	486	17	f	105
106	3	10	487	49.5	f	106
107	3	10	488	17.5	f	107
108	3	10	489	50	f	108
109	3	10	490	18	f	109
110	3	15	491	50.5	f	110
111	3	10	492	18.5	f	111
4	3	10	305	10.2	t	4
112	3	15	493	51	f	112
6	3	10	307	12.3	t	6
113	3	10	494	19	f	113
8	3	10	309	16.1	t	8
114	3	15	495	51.5	f	114
10	3	10	311	11.9	t	10
115	3	10	496	19.5	f	115
116	3	15	497	52	f	116
117	3	10	498	20	f	117
118	3	15	499	52.5	f	118
119	3	10	500	20.5	f	119
120	3	15	501	53	f	120
121	3	10	502	21	f	121
122	3	15	503	53.5	f	122
123	3	10	504	21.5	f	123
124	3	15	505	54	f	124
125	3	10	506	22	f	125
126	3	15	507	54.5	f	126
127	3	10	508	22.5	f	127
128	3	15	509	55	f	128
121	3	10	510	23	f	129
13	3	15	511	55.5	f	130
12	3	10	313	17.6	t	12
14	3	10	315	22.3	t	14
16	3	10	317	21	t	16
18	3	10	319	7.4	t	18
20	3	10	321	6.1	t	20
22	3	10	323	5.8	t	22
24	3	0	325	4.3	t	24
26	3	0	327	3.7	t	26
28	3	0	329	2.9	t	28
30	3	0	331	1.5	t	30
32	3	0	333	1	t	32
34	3	0	335	0.5	t	34
36	3	0	337	0	t	36
38	3	0	339	0	t	38
40	3	0	341	0.5	t	40
42	3	0	343	1	t	42
44	3	0	345	1.5	t	44
46	3	0	347	2	t	46
48	3	0	349	2.5	t	48
50	3	0	351	3	t	50
3	3	10	303	15.5	f	2
3	3	10	304	20	f	3
128	3	10	306	18.7	f	5
17	3	10	308	14.8	f	7
9	3	10	310	19.4	f	9
11	3	10	312	13.2	f	11
13	3	10	314	9.5	f	13
15	3	10	316	8.7	f	15
17	3	10	318	23.8	f	17
19	3	10	320	24.5	f	19
21	3	10	322	25.2	f	21
23	3	10	324	26.9	f	23
25	3	10	326	27.6	f	25
27	3	10	328	28.3	f	27
29	3	10	330	29	f	29
31	3	10	332	30	f	31
33	3	10	334	31.5	f	33
35	3	10	336	32	f	35
37	3	10	338	32.5	f	37
39	3	10	340	33	f	39
41	3	10	342	33.5	f	41
43	3	10	344	34	f	43
45	3	10	346	34.5	f	45
47	3	10	348	35	f	47
49	3	10	350	35.5	f	49
\.


--
-- Data for Name: tratta; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.tratta (idtratta, cittapartenza, cittaarrivo, scalo, nomecompagnia, nomecadenzagiornaliera) FROM stdin;
1	CAPRI	CASTELLAMMARE	\N	MareChiaroT	capri-castellammare primavera/estate 2024
2	CIVITAVECCHIA	OLBIA	\N	OndAnomala	civitavecchia-olbia infrasettimanale autunno 2024
3	ISCHIA	PONZA	\N	OndAnomala	ischia-ponza estate 2024
4	PONZA	ISCHIA	\N	OndAnomala	ponza-ischia estate 2024
5	NAPOLI	PANAREA	\N	MareChiaroT	napoli-panarea estate 2024
6	PANAREA	NAPOLI	\N	MareChiaroT	panarea-napoli estate 2024
7	NAPOLI	VENTOTENE	\N	MareChiaroT	napoli-ventotene estate 2024
8	VENTOTENE	NAPOLI	\N	MareChiaroT	ventotene-napoli estate 2024
9	CAGLIARI	SALERNO	\N	NaviExpress	cagliari-salerno bisettimanale inverno 2024
10	OLBIA	LIVORNO	\N	OndAnomala	olbia-livorno lunedi inverno 2024
11	LIVORNO	OLBIA	\N	OndAnomala	livorno-olbia lunedi inverno 2024
12	NAPOLI	ISCHIA	\N	OndAnomala	napoli-ischia primavera2024
13	POZZUOLI	ISCHIA	PROCIDA	NavItalia	corsa estiva 2024 pozzuoli-procida-ischia
14	SALERNO	CAGLIARI	\N	NaviExpress	salerno-cagliari weekend inverno 2024
15	CIVITAVECCHIA	OLBIA	\N	NaviExpress	civitavecchia-olbia infrasettimanale autunno 2024
16	GENOVA	NAPOLI	\N	NaviExpress	genova-napoli lun-mer-ven primavera 2024
17	CASTELLAMMARE	CAPRI	NAPOLI	NavItalia	castellammare-capri primavera/estate 2024
18	CAPRI	NAPOLI	\N	NavItalia	capri-napoli febbraio-settembre 2024
19	NAPOLI	CAPRI	\N	NavItalia	napoli-capri febbraio-settembre 2024
\.


--
-- Name: id_corsa_sequence; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.id_corsa_sequence', 963, true);


--
-- Name: id_tratta_sequence; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.id_tratta_sequence', 19, true);


--
-- Name: prenotazione_idprenotazione_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.prenotazione_idprenotazione_seq', 511, true);


--
-- Name: sequenza_id_passeggero; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.sequenza_id_passeggero', 128, true);


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
    ADD CONSTRAINT navigazione_pkey PRIMARY KEY (idtratta, codnatante);


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
-- Name: tratta tratta_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tratta
    ADD CONSTRAINT tratta_pkey PRIMARY KEY (idtratta);


--
-- Name: prenotazione after_insert_prenotazione; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER after_insert_prenotazione AFTER INSERT ON public.prenotazione FOR EACH ROW EXECUTE FUNCTION public.after_insert_prenotazione();


--
-- Name: tratta aggiungi_navigazione; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER aggiungi_navigazione AFTER INSERT ON public.tratta FOR EACH ROW EXECUTE FUNCTION public.aggiungi_navigazione();


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
-- Name: natante incrementa_numero_natanti; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER incrementa_numero_natanti AFTER INSERT ON public.natante FOR EACH ROW EXECUTE FUNCTION public.incrementa_numero_natanti();


--
-- Name: tratta insert_into_corsa; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER insert_into_corsa AFTER INSERT ON public.tratta FOR EACH ROW EXECUTE FUNCTION public.insert_into_corsa();


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
-- Name: prenotazione idcorsa; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.prenotazione
    ADD CONSTRAINT idcorsa FOREIGN KEY (idcorsa) REFERENCES public.corsa(idcorsa);


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
-- Name: corsa idtratta; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.corsa
    ADD CONSTRAINT idtratta FOREIGN KEY (idtratta) REFERENCES public.tratta(idtratta);


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
-- Name: navigazione navigazione_idtratta_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.navigazione
    ADD CONSTRAINT navigazione_idtratta_fkey FOREIGN KEY (idtratta) REFERENCES public.tratta(idtratta);


--
-- Name: prenotazione prenotazione_idpasseggero_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.prenotazione
    ADD CONSTRAINT prenotazione_idpasseggero_fkey FOREIGN KEY (idpasseggero) REFERENCES public.passeggero(idpasseggero);


--
-- Name: tratta tratta_nomecadenzagiornaliera_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tratta
    ADD CONSTRAINT tratta_nomecadenzagiornaliera_fkey FOREIGN KEY (nomecadenzagiornaliera) REFERENCES public.cadenzagiornaliera(nomecadenzagiornaliera);


--
-- Name: tratta tratta_nomecompagnia_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tratta
    ADD CONSTRAINT tratta_nomecompagnia_fkey FOREIGN KEY (nomecompagnia) REFERENCES public.compagniadinavigazione(nomecompagnia);


--
-- PostgreSQL database dump complete
--

