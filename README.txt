/*README
Il database allegato nei file SQL andrebbe importato su PostgreSQL attraverso la linea di comando con i seguenti passi.
1. Avviare postgresql;
2. Aprire la linea di comando avviandola come amministratore;
3. Andare nella cartella "bin" all'interno del percorso file di PostgreSQL nel disco locale;
4. Copiare il percorso file ed eseguire il comando "cd" sulla linea di comando col percorso file come argomento. (Es. cd C:\Program Files\PostgreSQL\15\bin);
5. Eseguire il comando "psql" con la sintassi "psql -h localhost -d database -U myuser -f path", dove database va rimpiazzato col database in cui importare il codice su Postgre, l'utente è l'utente in utilizzo su postgres, 
mentre path è il percorso dele file SQL;
 5.5 Qualora psql non dovesse funzionare, utilizzare invece il comando "pg_dump" con la sintassi: 
     "pg_dump -h localhost -U nome_utente -d nome_database -F c -f /percorso/destinazione/dump_personalizzato.backup";
6. In questo modo si sarà importato il DB nella sua interezza, già popolato;
In caso di eventuali errori, questo readme conterrà tutto il codice - commentato - così che nel peggiore dei casi lo si possa eseguire su SQL.

--Creazione Schema: 

CREATE SCHEMA IF NOT EXISTS public
    AUTHORIZATION pg_database_owner;

COMMENT ON SCHEMA public
    IS 'standard public schema';

GRANT USAGE ON SCHEMA public TO PUBLIC;

GRANT ALL ON SCHEMA public TO pg_database_owner;

--Creazione delle 10 tuple con relativi trigger:

CREATE TABLE IF NOT EXISTS public.bigliettoridotto
(
    codbigliettor integer NOT NULL,
    prezzo double precision DEFAULT 10.50,
    nominativo character varying(100) COLLATE pg_catalog."default" NOT NULL,
    idpasseggero integer,
    CONSTRAINT bigliettoridotto_pkey PRIMARY KEY (codbigliettor),
    CONSTRAINT idpasseggero FOREIGN KEY (idpasseggero)
        REFERENCES public.passeggero (idpasseggero) MATCH SIMPLE
        ON UPDATE NO ACTION
        ON DELETE NO ACTION
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS public.bigliettoridotto
    OWNER to postgres;


CREATE TABLE IF NOT EXISTS public.bigliettoridotto
(
    codbigliettor integer NOT NULL,
    prezzo double precision DEFAULT 10.50,
    nominativo character varying(100) COLLATE pg_catalog."default" NOT NULL,
    idpasseggero integer,
    CONSTRAINT bigliettoridotto_pkey PRIMARY KEY (codbigliettor),
    CONSTRAINT idpasseggero FOREIGN KEY (idpasseggero)
        REFERENCES public.passeggero (idpasseggero) MATCH SIMPLE
        ON UPDATE NO ACTION
        ON DELETE NO ACTION
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS public.bigliettoridotto
    OWNER to postgres;


CREATE TABLE IF NOT EXISTS public.cadenzagiornaliera
(
    datainizio date NOT NULL,
    datafine date NOT NULL,
    giornosettimanale character varying(70) COLLATE pg_catalog."default" NOT NULL,
    orariopartenza time without time zone NOT NULL,
    orarioarrivo time without time zone NOT NULL,
    nomecadenzagiornaliera character varying(100) COLLATE pg_catalog."default" NOT NULL,
    CONSTRAINT cadenzagiornaliera_pkey PRIMARY KEY (nomecadenzagiornaliera),
    CONSTRAINT ck_date CHECK (datainizio < datafine)
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS public.cadenzagiornaliera
    OWNER to postgres;


CREATE TABLE IF NOT EXISTS public.compagniadinavigazione
(
    nomecompagnia character varying(50) COLLATE pg_catalog."default" NOT NULL,
    numeronatanti integer DEFAULT 0,
    telefono character varying(15) COLLATE pg_catalog."default",
    mail character varying(50) COLLATE pg_catalog."default",
    sitoweb character varying(50) COLLATE pg_catalog."default",
    CONSTRAINT compagniadinavigazione_pkey PRIMARY KEY (nomecompagnia),
    CONSTRAINT mail UNIQUE (mail),
    CONSTRAINT sitoweb UNIQUE (sitoweb),
    CONSTRAINT telefono UNIQUE (telefono)
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS public.compagniadinavigazione
    OWNER to postgres;


CREATE TABLE IF NOT EXISTS public.corsa
(
    idcorsa character varying(15) COLLATE pg_catalog."default" NOT NULL,
    nomecompagnia character varying(30) COLLATE pg_catalog."default",
    cittapartenza character varying(30) COLLATE pg_catalog."default" NOT NULL,
    cittaarrivo character varying(30) COLLATE pg_catalog."default" NOT NULL,
    scalo character varying(30) COLLATE pg_catalog."default",
    ritardo character varying(4) COLLATE pg_catalog."default",
    disponibilita integer,
    nomecadenzagiornaliera character varying(100) COLLATE pg_catalog."default",
    disponibilitaauto integer,
    CONSTRAINT corsa_pkey PRIMARY KEY (idcorsa),
    CONSTRAINT corsa_nomecompagnia_fkey FOREIGN KEY (nomecompagnia)
        REFERENCES public.compagniadinavigazione (nomecompagnia) MATCH SIMPLE
        ON UPDATE NO ACTION
        ON DELETE NO ACTION,
    CONSTRAINT nomecadenzagiornaliera FOREIGN KEY (nomecadenzagiornaliera)
        REFERENCES public.cadenzagiornaliera (nomecadenzagiornaliera) MATCH SIMPLE
        ON UPDATE NO ACTION
        ON DELETE NO ACTION
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS public.corsa
    OWNER to postgres;

-- Trigger: aggiungi_navigazione

-- DROP TRIGGER IF EXISTS aggiungi_navigazione ON public.corsa;

CREATE OR REPLACE TRIGGER aggiungi_navigazione
    AFTER INSERT
    ON public.corsa
    FOR EACH ROW
    EXECUTE FUNCTION public.aggiungi_navigazione();

-- Trigger: imposta_disponibilita

-- DROP TRIGGER IF EXISTS imposta_disponibilita ON public.corsa;

CREATE OR REPLACE TRIGGER imposta_disponibilita
    AFTER INSERT
    ON public.corsa
    FOR EACH ROW
    EXECUTE FUNCTION public.imposta_disponibilita();

-- Trigger: modifica_ritardo

-- DROP TRIGGER IF EXISTS modifica_ritardo ON public.corsa;

CREATE OR REPLACE TRIGGER modifica_ritardo
    AFTER UPDATE OF ritardo
    ON public.corsa
    FOR EACH ROW
    EXECUTE FUNCTION public.modifica_ritardo();



CREATE TABLE IF NOT EXISTS public.indirizzosocial
(
    indirizzo character varying(50) COLLATE pg_catalog."default" NOT NULL,
    nomecompagnia character varying(50) COLLATE pg_catalog."default",
    CONSTRAINT indirizzosocial_pkey PRIMARY KEY (indirizzo),
    CONSTRAINT indirizzosocial_nomecompagnia_fkey FOREIGN KEY (nomecompagnia)
        REFERENCES public.compagniadinavigazione (nomecompagnia) MATCH SIMPLE
        ON UPDATE NO ACTION
        ON DELETE NO ACTION
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS public.indirizzosocial
    OWNER to postgres;



CREATE TABLE IF NOT EXISTS public.natante
(
    codnatante character varying(15) COLLATE pg_catalog."default" NOT NULL,
    nomecompagnia character varying(30) COLLATE pg_catalog."default",
    tiponatante character varying(30) COLLATE pg_catalog."default",
    capienzapasseggeri integer,
    capienzaautomezzi integer,
    CONSTRAINT natante_pkey PRIMARY KEY (codnatante),
    CONSTRAINT natante_nomecompagnia_fkey FOREIGN KEY (nomecompagnia)
        REFERENCES public.compagniadinavigazione (nomecompagnia) MATCH SIMPLE
        ON UPDATE NO ACTION
        ON DELETE NO ACTION,
    CONSTRAINT ck_capienzapasseggeri CHECK (capienzapasseggeri > 0),
    CONSTRAINT ck_tiponatante CHECK (tiponatante::text = ANY (ARRAY['traghetto'::character varying::text, 'aliscafo'::character varying::text, 'motonave'::character varying::text, 'altro'::character varying::text]))
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS public.natante
    OWNER to postgres;

-- Trigger: incrementa_numero_natanti

-- DROP TRIGGER IF EXISTS incrementa_numero_natanti ON public.natante;

CREATE OR REPLACE TRIGGER incrementa_numero_natanti
    AFTER INSERT
    ON public.natante
    FOR EACH ROW
    EXECUTE FUNCTION public.incrementa_numero_natanti();



CREATE TABLE IF NOT EXISTS public.navigazione
(
    idcorsa character varying(15) COLLATE pg_catalog."default" NOT NULL,
    codnatante character varying(15) COLLATE pg_catalog."default" NOT NULL,
    CONSTRAINT navigazione_pkey PRIMARY KEY (idcorsa, codnatante),
    CONSTRAINT navigazione_codnatante_fkey FOREIGN KEY (codnatante)
        REFERENCES public.natante (codnatante) MATCH SIMPLE
        ON UPDATE NO ACTION
        ON DELETE NO ACTION,
    CONSTRAINT navigazione_idcorsa_fkey FOREIGN KEY (idcorsa)
        REFERENCES public.corsa (idcorsa) MATCH SIMPLE
        ON UPDATE NO ACTION
        ON DELETE NO ACTION
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS public.navigazione
    OWNER to postgres;


CREATE TABLE IF NOT EXISTS public.passeggero
(
    idpasseggero integer NOT NULL,
    nome character varying(50) COLLATE pg_catalog."default" NOT NULL,
    cognome character varying(50) COLLATE pg_catalog."default" NOT NULL,
    datanascita date NOT NULL,
    CONSTRAINT passeggero_pkey PRIMARY KEY (idpasseggero)
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS public.passeggero
    OWNER to postgres;

-- Trigger: incrementa_id_passeggero

-- DROP TRIGGER IF EXISTS incrementa_id_passeggero ON public.passeggero;

CREATE OR REPLACE TRIGGER incrementa_id_passeggero
    BEFORE INSERT
    ON public.passeggero
    FOR EACH ROW
    EXECUTE FUNCTION public.incrementa_id_passeggero();



CREATE TABLE IF NOT EXISTS public.prenotazione
(
    idcorsa character varying(15) COLLATE pg_catalog."default" NOT NULL,
    idpasseggero integer NOT NULL,
    sovrapprezzoprenotazione double precision DEFAULT 3.00,
    sovrapprezzobagagli double precision,
    idprenotazione integer NOT NULL DEFAULT nextval('prenotazione_idprenotazione_seq'::regclass),
    peso_bagaglio double precision,
    auto boolean DEFAULT false,
    CONSTRAINT prenotazione_pkey PRIMARY KEY (idprenotazione),
    CONSTRAINT prenotazione_idcorsa_fkey FOREIGN KEY (idcorsa)
        REFERENCES public.corsa (idcorsa) MATCH SIMPLE
        ON UPDATE NO ACTION
        ON DELETE NO ACTION,
    CONSTRAINT prenotazione_idpasseggero_fkey FOREIGN KEY (idpasseggero)
        REFERENCES public.passeggero (idpasseggero) MATCH SIMPLE
        ON UPDATE NO ACTION
        ON DELETE NO ACTION
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS public.prenotazione
    OWNER to postgres;

-- Trigger: after_insert_prenotazione

-- DROP TRIGGER IF EXISTS after_insert_prenotazione ON public.prenotazione;

CREATE OR REPLACE TRIGGER after_insert_prenotazione
    AFTER INSERT
    ON public.prenotazione
    FOR EACH ROW
    EXECUTE FUNCTION public.after_insert_prenotazione();

-- Trigger: diminuisci_disponibilita

-- DROP TRIGGER IF EXISTS diminuisci_disponibilita ON public.prenotazione;

CREATE OR REPLACE TRIGGER diminuisci_disponibilita
    AFTER INSERT
    ON public.prenotazione
    FOR EACH ROW
    EXECUTE FUNCTION public.diminuisci_disponibilita();

-- Trigger: diminuisci_disponibilita_auto

-- DROP TRIGGER IF EXISTS diminuisci_disponibilita_auto ON public.prenotazione;

CREATE OR REPLACE TRIGGER diminuisci_disponibilita_auto
    AFTER INSERT
    ON public.prenotazione
    FOR EACH ROW
    EXECUTE FUNCTION public.diminuisci_disponibilita_auto();

-- Trigger: elimina_prenotazione

-- DROP TRIGGER IF EXISTS elimina_prenotazione ON public.prenotazione;

CREATE OR REPLACE TRIGGER elimina_prenotazione
    AFTER DELETE
    ON public.prenotazione
    FOR EACH ROW
    EXECUTE FUNCTION public.elimina_prenotazione();

-- Trigger: prezzo_bagaglio

-- DROP TRIGGER IF EXISTS prezzo_bagaglio ON public.prenotazione;

CREATE OR REPLACE TRIGGER prezzo_bagaglio
    BEFORE INSERT
    ON public.prenotazione
    FOR EACH ROW
    EXECUTE FUNCTION public.prezzo_bagaglio();

-- Trigger: setta_sovrapprezzoprenotazione

-- DROP TRIGGER IF EXISTS setta_sovrapprezzoprenotazione ON public.prenotazione;

CREATE OR REPLACE TRIGGER setta_sovrapprezzoprenotazione
    BEFORE INSERT
    ON public.prenotazione
    FOR EACH ROW
    EXECUTE FUNCTION public.setta_sovrapprezzoprenotazione();

-- Trigger: verifica_disponibilita_auto

-- DROP TRIGGER IF EXISTS verifica_disponibilita_auto ON public.prenotazione;

CREATE OR REPLACE TRIGGER verifica_disponibilita_auto
    BEFORE INSERT
    ON public.prenotazione
    FOR EACH ROW
    EXECUTE FUNCTION public.verifica_disponibilita_auto();

--Creazione delle funzioni:

CREATE OR REPLACE FUNCTION public.after_insert_prenotazione()
    RETURNS trigger
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE NOT LEAKPROOF
AS $BODY$
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
$BODY$;

ALTER FUNCTION public.after_insert_prenotazione()
    OWNER TO postgres;

COMMENT ON FUNCTION public.after_insert_prenotazione()
    IS '-- funzione che, dopo l''inserimento di una tupla in prenotazione, attiva il trigger che permette di aggiungere una tupla corrispondente in bigliettoridotto se l''età è minore di 18, oppure in bigliettointero se l''età è maggiore di 18. Questa funzione inoltre permette di indicare l''eventuale sovrapprezzo della prenotazione o il sovrapprezzo dei bagagli, e di diminuire la disponibilità nella tabella corsa';


CREATE OR REPLACE FUNCTION public.aggiungi_navigazione()
    RETURNS trigger
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE NOT LEAKPROOF
AS $BODY$
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
$BODY$;

ALTER FUNCTION public.aggiungi_navigazione()
    OWNER TO postgres;


CREATE OR REPLACE FUNCTION public.diminuisci_disponibilita()
    RETURNS trigger
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE NOT LEAKPROOF
AS $BODY$
begin
	
	UPDATE corsa
    SET disponibilita = disponibilita - 1
    WHERE idcorsa = NEW.idcorsa;

    RETURN NEW;
		
end;
$BODY$;

ALTER FUNCTION public.diminuisci_disponibilita()
    OWNER TO postgres;

CREATE OR REPLACE FUNCTION public.diminuisci_disponibilita_auto()
    RETURNS trigger
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE NOT LEAKPROOF
AS $BODY$
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
$BODY$;

ALTER FUNCTION public.diminuisci_disponibilita_auto()
    OWNER TO postgres;


CREATE OR REPLACE FUNCTION public.elimina_prenotazione()
    RETURNS trigger
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE NOT LEAKPROOF
AS $BODY$
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
$BODY$;

ALTER FUNCTION public.elimina_prenotazione()
    OWNER TO postgres;


CREATE OR REPLACE FUNCTION public.imposta_disponibilita()
    RETURNS trigger
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE NOT LEAKPROOF
AS $BODY$
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
$BODY$;

ALTER FUNCTION public.imposta_disponibilita()
    OWNER TO postgres;


CREATE OR REPLACE FUNCTION public.incrementa_id_passeggero()
    RETURNS trigger
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE NOT LEAKPROOF
AS $BODY$
 
begin

	new.idpasseggero = nextval('sequenza_id_passeggero'); --funzione che restituisce il prossimo elemento nella sequenza
	return new;
	
end;
$BODY$;

ALTER FUNCTION public.incrementa_id_passeggero()
    OWNER TO postgres;


CREATE OR REPLACE FUNCTION public.incrementa_numero_natanti()
    RETURNS trigger
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE NOT LEAKPROOF
AS $BODY$
begin
	
	update compagniadinavigazione
	set numeronatanti = numeronatanti + 1
	where nomecompagnia = new.nomecompagnia;
	
	return new;
end;
$BODY$;

ALTER FUNCTION public.incrementa_numero_natanti()
    OWNER TO postgres;


CREATE OR REPLACE FUNCTION public.modifica_ritardo()
    RETURNS trigger
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE NOT LEAKPROOF
AS $BODY$
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
$BODY$;

ALTER FUNCTION public.modifica_ritardo()
    OWNER TO postgres;


CREATE OR REPLACE FUNCTION public.prezzo_bagaglio()
    RETURNS trigger
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE NOT LEAKPROOF
AS $BODY$

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
$BODY$;

ALTER FUNCTION public.prezzo_bagaglio()
    OWNER TO postgres;


CREATE OR REPLACE FUNCTION public.setta_sovrapprezzoprenotazione()
    RETURNS trigger
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE NOT LEAKPROOF
AS $BODY$
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
$BODY$;

ALTER FUNCTION public.setta_sovrapprezzoprenotazione()
    OWNER TO postgres;


CREATE OR REPLACE FUNCTION public.verifica_disponibilita_auto()
    RETURNS trigger
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE NOT LEAKPROOF
AS $BODY$
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
-- la funzione controlla anzitutto se ci sono ancora posti auto disponibili
	if disponibilita_auto <= 0 then 
		raise exception 'I posti auto sono esauriti.';
	end if;
	
	if new.auto = true and tipo <> 'traghetto' then
		update prenotazione
		set auto = false
		where idcorsa = new.idcorsa;
-- nel caso una prenotazione sia fatta su un tipo di nave che non ha posti auto, c'è un'exception:
		raise exception 'Impossibile aggiungere l''auto, perchè l''imbarcazione non lo permette';

	end if;
	
	return new;
end;
$BODY$;

ALTER FUNCTION public.verifica_disponibilita_auto()
    OWNER TO postgres;


--Per completezza, sono presenti anche le SEQUENCE relative all'Idprenotazione e all'Idpasseggero, 
--primary key delle rispettive tuple:

CREATE SEQUENCE IF NOT EXISTS public.prenotazione_idprenotazione_seq
    INCREMENT 1
    START 1
    MINVALUE 1
    MAXVALUE 2147483647
    CACHE 1
    OWNED BY prenotazione.idprenotazione;

ALTER SEQUENCE public.prenotazione_idprenotazione_seq
    OWNER TO postgres;

CREATE SEQUENCE IF NOT EXISTS public.sequenza_id_passeggero
    INCREMENT 1
    START 1
    MINVALUE 1
    MAXVALUE 9223372036854775807
    CACHE 1;

ALTER SEQUENCE public.sequenza_id_passeggero
    OWNER TO postgres;

*/