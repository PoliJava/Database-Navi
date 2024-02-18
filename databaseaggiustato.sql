PGDMP     #    (                |            progettofatt    15.5    15.5 T    y           0    0    ENCODING    ENCODING        SET client_encoding = 'UTF8';
                      false            z           0    0 
   STDSTRINGS 
   STDSTRINGS     (   SET standard_conforming_strings = 'on';
                      false            {           0    0 
   SEARCHPATH 
   SEARCHPATH     8   SELECT pg_catalog.set_config('search_path', '', false);
                      false            |           1262    25016    progettofatt    DATABASE        CREATE DATABASE progettofatt WITH TEMPLATE = template0 ENCODING = 'UTF8' LOCALE_PROVIDER = libc LOCALE = 'Italian_Italy.1252';
    DROP DATABASE progettofatt;
                postgres    false            �            1255    25017    after_insert_prenotazione()    FUNCTION     �  CREATE FUNCTION public.after_insert_prenotazione() RETURNS trigger
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
 2   DROP FUNCTION public.after_insert_prenotazione();
       public          postgres    false            }           0    0 $   FUNCTION after_insert_prenotazione()    COMMENT     �  COMMENT ON FUNCTION public.after_insert_prenotazione() IS '-- funzione che, dopo l''inserimento di una tupla in prenotazione, attiva il trigger che permette di aggiungere una tupla corrispondente in bigliettoridotto se l''età è minore di 18, oppure in bigliettointero se l''età è maggiore di 18. Questa funzione inoltre permette di indicare l''eventuale sovrapprezzo della prenotazione o il sovrapprezzo dei bagagli, e di diminuire la disponibilità nella tabella corsa';
          public          postgres    false    241            �            1255    25018    aggiungi_navigazione()    FUNCTION     �  CREATE FUNCTION public.aggiungi_navigazione() RETURNS trigger
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
 -   DROP FUNCTION public.aggiungi_navigazione();
       public          postgres    false            �            1255    25019    diminuisci_disponibilita()    FUNCTION     �  CREATE FUNCTION public.diminuisci_disponibilita() RETURNS trigger
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
 1   DROP FUNCTION public.diminuisci_disponibilita();
       public          postgres    false            �            1255    25020    elimina_prenotazione()    FUNCTION     �  CREATE FUNCTION public.elimina_prenotazione() RETURNS trigger
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
 -   DROP FUNCTION public.elimina_prenotazione();
       public          postgres    false            �            1255    25021    imposta_disponibilita()    FUNCTION     =  CREATE FUNCTION public.imposta_disponibilita() RETURNS trigger
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
 .   DROP FUNCTION public.imposta_disponibilita();
       public          postgres    false            �            1255    25022    incrementa_numero_natanti()    FUNCTION     �   CREATE FUNCTION public.incrementa_numero_natanti() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
	
	update compagniadinavigazione
	set numeronatanti = numeronatanti + 1
	where nomecompagnia = new.nomecompagnia;
	
	return new;
end;
$$;
 2   DROP FUNCTION public.incrementa_numero_natanti();
       public          postgres    false            �            1255    25023    insert_into_corsa()    FUNCTION     )  CREATE FUNCTION public.insert_into_corsa() RETURNS trigger
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
	
	-- questo loop assegna ad ogni iterazione il valore numerico del giorno della settimana di una data a "giorno"
	
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
		
		-- questo loop genera una serie di date comprese fra la data inizio e la data della fine
		
        FOR data_giorno IN 
			SELECT generate_series(datainizio, datafine, '1 day'::interval) 
			FROM CADENZAGIORNALIERA 
			WHERE nomeCadenzaGiornaliera = new.nomecadenzagiornaliera 
				
		LOOP
			--se il giorno della data corrente corrisponde a "giorno_numero" viene inserita una nuova riga nella tabella corsa
			 IF giorno_numero =  to_char(data_giorno, 'D')::integer THEN
                INSERT INTO CORSA (Disponibilitapasseggero, Disponibilitaauto, Giorno, idTratta)
                VALUES (disponibilitapasseggero, disponibilitaauto, data_giorno, NEW.IdTratta);
            END IF;
			-- questo processo è ripetuto per ogni giorno specificato nella cadenzagiornaliera, così da generare corse nelle date rientranti nella cadenza
        END LOOP;
    END LOOP;
	
   
RETURN NEW;
END;
$$;
 *   DROP FUNCTION public.insert_into_corsa();
       public          postgres    false            �            1255    25024    modifica_ritardo()    FUNCTION       CREATE FUNCTION public.modifica_ritardo() RETURNS trigger
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
 )   DROP FUNCTION public.modifica_ritardo();
       public          postgres    false            �            1255    25025    prezzo_bagaglio()    FUNCTION     j  CREATE FUNCTION public.prezzo_bagaglio() RETURNS trigger
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
 (   DROP FUNCTION public.prezzo_bagaglio();
       public          postgres    false            �            1255    25026     setta_sovrapprezzoprenotazione()    FUNCTION     �  CREATE FUNCTION public.setta_sovrapprezzoprenotazione() RETURNS trigger
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
	--il giorno della corsa viene conservato in una variabile								
	select extract(year from age(data_corsa, current_date)) into tempo_year;
	select extract(month from age(data_corsa, current_date)) into tempo_month;
	select extract(day from age(data_corsa, current_date)) into tempo_day;
	--la funzione separa giorno mese e anno dalla data
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
 7   DROP FUNCTION public.setta_sovrapprezzoprenotazione();
       public          postgres    false            �            1255    25027    verifica_disponibilita_auto()    FUNCTION     K  CREATE FUNCTION public.verifica_disponibilita_auto() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
declare
	tipo natante.tiponatante%type;
	disponibilita_auto integer;
begin
	--andiamo ad estrarre il tipo di un natante dalla corsa
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
		-- estraiamo la disponibilità auto dalla nuova corsa
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
 4   DROP FUNCTION public.verifica_disponibilita_auto();
       public          postgres    false            �            1259    25028    bigliettointero    TABLE     �   CREATE TABLE public.bigliettointero (
    codbigliettoi integer NOT NULL,
    prezzo double precision DEFAULT 15.50,
    nominativo character varying(100) NOT NULL,
    idpasseggero integer
);
 #   DROP TABLE public.bigliettointero;
       public         heap    postgres    false            �            1259    25032    bigliettoridotto    TABLE     �   CREATE TABLE public.bigliettoridotto (
    codbigliettor integer NOT NULL,
    prezzo double precision DEFAULT 10.50,
    nominativo character varying(100) NOT NULL,
    idpasseggero integer
);
 $   DROP TABLE public.bigliettoridotto;
       public         heap    postgres    false            �            1259    25036    cadenzagiornaliera    TABLE     u  CREATE TABLE public.cadenzagiornaliera (
    datainizio date NOT NULL,
    datafine date NOT NULL,
    giornosettimanale character varying(70) NOT NULL,
    orariopartenza time without time zone NOT NULL,
    orarioarrivo time without time zone NOT NULL,
    nomecadenzagiornaliera character varying(100) NOT NULL,
    CONSTRAINT ck_date CHECK ((datainizio < datafine))
);
 &   DROP TABLE public.cadenzagiornaliera;
       public         heap    postgres    false            �            1259    25040    compagniadinavigazione    TABLE     �   CREATE TABLE public.compagniadinavigazione (
    nomecompagnia character varying(50) NOT NULL,
    numeronatanti integer DEFAULT 0,
    telefono character varying(15),
    mail character varying(50),
    sitoweb character varying(50)
);
 *   DROP TABLE public.compagniadinavigazione;
       public         heap    postgres    false            �            1259    25044    id_corsa_sequence    SEQUENCE     z   CREATE SEQUENCE public.id_corsa_sequence
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 (   DROP SEQUENCE public.id_corsa_sequence;
       public          postgres    false            �            1259    25045    corsa    TABLE     �   CREATE TABLE public.corsa (
    idcorsa integer DEFAULT nextval('public.id_corsa_sequence'::regclass) NOT NULL,
    ritardo character varying(4),
    disponibilitaauto integer,
    disponibilitapasseggero integer,
    giorno date,
    idtratta integer
);
    DROP TABLE public.corsa;
       public         heap    postgres    false    218            �            1259    25049    id_tratta_sequence    SEQUENCE     {   CREATE SEQUENCE public.id_tratta_sequence
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 )   DROP SEQUENCE public.id_tratta_sequence;
       public          postgres    false            �            1259    25050    indirizzosocial    TABLE        CREATE TABLE public.indirizzosocial (
    indirizzo character varying(50) NOT NULL,
    nomecompagnia character varying(50)
);
 #   DROP TABLE public.indirizzosocial;
       public         heap    postgres    false            �            1259    25053    natante    TABLE     
  CREATE TABLE public.natante (
    codnatante character varying(15) NOT NULL,
    nomecompagnia character varying(30),
    tiponatante character varying(30),
    capienzapasseggeri integer,
    capienzaautomezzi integer,
    CONSTRAINT ck_capienzapasseggeri CHECK ((capienzapasseggeri > 0)),
    CONSTRAINT ck_tiponatante CHECK (((tiponatante)::text = ANY (ARRAY[('traghetto'::character varying)::text, ('aliscafo'::character varying)::text, ('motonave'::character varying)::text, ('altro'::character varying)::text])))
);
    DROP TABLE public.natante;
       public         heap    postgres    false            �            1259    25058    navigazione    TABLE     r   CREATE TABLE public.navigazione (
    idtratta integer NOT NULL,
    codnatante character varying(15) NOT NULL
);
    DROP TABLE public.navigazione;
       public         heap    postgres    false            �            1259    25061    sequenza_id_passeggero    SEQUENCE        CREATE SEQUENCE public.sequenza_id_passeggero
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 -   DROP SEQUENCE public.sequenza_id_passeggero;
       public          postgres    false            �            1259    25062 
   passeggero    TABLE     �   CREATE TABLE public.passeggero (
    idpasseggero integer DEFAULT nextval('public.sequenza_id_passeggero'::regclass) NOT NULL,
    nome character varying(50) NOT NULL,
    cognome character varying(50) NOT NULL,
    datanascita date NOT NULL
);
    DROP TABLE public.passeggero;
       public         heap    postgres    false    224            �            1259    25066    prenotazione    TABLE     ,  CREATE TABLE public.prenotazione (
    idpasseggero integer NOT NULL,
    sovrapprezzoprenotazione double precision DEFAULT 3.00,
    sovrapprezzobagagli double precision,
    idprenotazione integer NOT NULL,
    peso_bagaglio double precision,
    auto boolean DEFAULT false,
    idcorsa integer
);
     DROP TABLE public.prenotazione;
       public         heap    postgres    false            �            1259    25071    prenotazione_idprenotazione_seq    SEQUENCE     �   CREATE SEQUENCE public.prenotazione_idprenotazione_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 6   DROP SEQUENCE public.prenotazione_idprenotazione_seq;
       public          postgres    false    226            ~           0    0    prenotazione_idprenotazione_seq    SEQUENCE OWNED BY     c   ALTER SEQUENCE public.prenotazione_idprenotazione_seq OWNED BY public.prenotazione.idprenotazione;
          public          postgres    false    227            �            1259    25072    tratta    TABLE     t  CREATE TABLE public.tratta (
    idtratta integer DEFAULT nextval('public.id_tratta_sequence'::regclass) NOT NULL,
    cittapartenza character varying(30) NOT NULL,
    cittaarrivo character varying(30) NOT NULL,
    scalo character varying(30) DEFAULT NULL::character varying,
    nomecompagnia character varying(30),
    nomecadenzagiornaliera character varying(100)
);
    DROP TABLE public.tratta;
       public         heap    postgres    false    220            �           2604    25077    prenotazione idprenotazione    DEFAULT     �   ALTER TABLE ONLY public.prenotazione ALTER COLUMN idprenotazione SET DEFAULT nextval('public.prenotazione_idprenotazione_seq'::regclass);
 J   ALTER TABLE public.prenotazione ALTER COLUMN idprenotazione DROP DEFAULT;
       public          postgres    false    227    226            h          0    25028    bigliettointero 
   TABLE DATA           Z   COPY public.bigliettointero (codbigliettoi, prezzo, nominativo, idpasseggero) FROM stdin;
    public          postgres    false    214   \�       i          0    25032    bigliettoridotto 
   TABLE DATA           [   COPY public.bigliettoridotto (codbigliettor, prezzo, nominativo, idpasseggero) FROM stdin;
    public          postgres    false    215   3�       j          0    25036    cadenzagiornaliera 
   TABLE DATA           �   COPY public.cadenzagiornaliera (datainizio, datafine, giornosettimanale, orariopartenza, orarioarrivo, nomecadenzagiornaliera) FROM stdin;
    public          postgres    false    216   1�       k          0    25040    compagniadinavigazione 
   TABLE DATA           g   COPY public.compagniadinavigazione (nomecompagnia, numeronatanti, telefono, mail, sitoweb) FROM stdin;
    public          postgres    false    217   (�       m          0    25045    corsa 
   TABLE DATA           o   COPY public.corsa (idcorsa, ritardo, disponibilitaauto, disponibilitapasseggero, giorno, idtratta) FROM stdin;
    public          postgres    false    219   Ϯ       o          0    25050    indirizzosocial 
   TABLE DATA           C   COPY public.indirizzosocial (indirizzo, nomecompagnia) FROM stdin;
    public          postgres    false    221   ��       p          0    25053    natante 
   TABLE DATA           p   COPY public.natante (codnatante, nomecompagnia, tiponatante, capienzapasseggeri, capienzaautomezzi) FROM stdin;
    public          postgres    false    222   f�       q          0    25058    navigazione 
   TABLE DATA           ;   COPY public.navigazione (idtratta, codnatante) FROM stdin;
    public          postgres    false    223   �       s          0    25062 
   passeggero 
   TABLE DATA           N   COPY public.passeggero (idpasseggero, nome, cognome, datanascita) FROM stdin;
    public          postgres    false    225   d�       t          0    25066    prenotazione 
   TABLE DATA           �   COPY public.prenotazione (idpasseggero, sovrapprezzoprenotazione, sovrapprezzobagagli, idprenotazione, peso_bagaglio, auto, idcorsa) FROM stdin;
    public          postgres    false    226   |�       v          0    25072    tratta 
   TABLE DATA           t   COPY public.tratta (idtratta, cittapartenza, cittaarrivo, scalo, nomecompagnia, nomecadenzagiornaliera) FROM stdin;
    public          postgres    false    228   ��                  0    0    id_corsa_sequence    SEQUENCE SET     A   SELECT pg_catalog.setval('public.id_corsa_sequence', 963, true);
          public          postgres    false    218            �           0    0    id_tratta_sequence    SEQUENCE SET     A   SELECT pg_catalog.setval('public.id_tratta_sequence', 19, true);
          public          postgres    false    220            �           0    0    prenotazione_idprenotazione_seq    SEQUENCE SET     O   SELECT pg_catalog.setval('public.prenotazione_idprenotazione_seq', 511, true);
          public          postgres    false    227            �           0    0    sequenza_id_passeggero    SEQUENCE SET     F   SELECT pg_catalog.setval('public.sequenza_id_passeggero', 128, true);
          public          postgres    false    224            �           2606    25079 $   bigliettointero bigliettointero_pkey 
   CONSTRAINT     m   ALTER TABLE ONLY public.bigliettointero
    ADD CONSTRAINT bigliettointero_pkey PRIMARY KEY (codbigliettoi);
 N   ALTER TABLE ONLY public.bigliettointero DROP CONSTRAINT bigliettointero_pkey;
       public            postgres    false    214            �           2606    25081 &   bigliettoridotto bigliettoridotto_pkey 
   CONSTRAINT     o   ALTER TABLE ONLY public.bigliettoridotto
    ADD CONSTRAINT bigliettoridotto_pkey PRIMARY KEY (codbigliettor);
 P   ALTER TABLE ONLY public.bigliettoridotto DROP CONSTRAINT bigliettoridotto_pkey;
       public            postgres    false    215            �           2606    25083 *   cadenzagiornaliera cadenzagiornaliera_pkey 
   CONSTRAINT     |   ALTER TABLE ONLY public.cadenzagiornaliera
    ADD CONSTRAINT cadenzagiornaliera_pkey PRIMARY KEY (nomecadenzagiornaliera);
 T   ALTER TABLE ONLY public.cadenzagiornaliera DROP CONSTRAINT cadenzagiornaliera_pkey;
       public            postgres    false    216            �           2606    25085 2   compagniadinavigazione compagniadinavigazione_pkey 
   CONSTRAINT     {   ALTER TABLE ONLY public.compagniadinavigazione
    ADD CONSTRAINT compagniadinavigazione_pkey PRIMARY KEY (nomecompagnia);
 \   ALTER TABLE ONLY public.compagniadinavigazione DROP CONSTRAINT compagniadinavigazione_pkey;
       public            postgres    false    217            �           2606    25087    corsa corsa_pkey 
   CONSTRAINT     S   ALTER TABLE ONLY public.corsa
    ADD CONSTRAINT corsa_pkey PRIMARY KEY (idcorsa);
 :   ALTER TABLE ONLY public.corsa DROP CONSTRAINT corsa_pkey;
       public            postgres    false    219            �           2606    25089 $   indirizzosocial indirizzosocial_pkey 
   CONSTRAINT     i   ALTER TABLE ONLY public.indirizzosocial
    ADD CONSTRAINT indirizzosocial_pkey PRIMARY KEY (indirizzo);
 N   ALTER TABLE ONLY public.indirizzosocial DROP CONSTRAINT indirizzosocial_pkey;
       public            postgres    false    221            �           2606    25091    compagniadinavigazione mail 
   CONSTRAINT     V   ALTER TABLE ONLY public.compagniadinavigazione
    ADD CONSTRAINT mail UNIQUE (mail);
 E   ALTER TABLE ONLY public.compagniadinavigazione DROP CONSTRAINT mail;
       public            postgres    false    217            �           2606    25093    natante natante_pkey 
   CONSTRAINT     Z   ALTER TABLE ONLY public.natante
    ADD CONSTRAINT natante_pkey PRIMARY KEY (codnatante);
 >   ALTER TABLE ONLY public.natante DROP CONSTRAINT natante_pkey;
       public            postgres    false    222            �           2606    25095    navigazione navigazione_pkey 
   CONSTRAINT     l   ALTER TABLE ONLY public.navigazione
    ADD CONSTRAINT navigazione_pkey PRIMARY KEY (idtratta, codnatante);
 F   ALTER TABLE ONLY public.navigazione DROP CONSTRAINT navigazione_pkey;
       public            postgres    false    223    223            �           2606    25097    passeggero passeggero_pkey 
   CONSTRAINT     b   ALTER TABLE ONLY public.passeggero
    ADD CONSTRAINT passeggero_pkey PRIMARY KEY (idpasseggero);
 D   ALTER TABLE ONLY public.passeggero DROP CONSTRAINT passeggero_pkey;
       public            postgres    false    225            �           2606    25099    prenotazione prenotazione_pkey 
   CONSTRAINT     h   ALTER TABLE ONLY public.prenotazione
    ADD CONSTRAINT prenotazione_pkey PRIMARY KEY (idprenotazione);
 H   ALTER TABLE ONLY public.prenotazione DROP CONSTRAINT prenotazione_pkey;
       public            postgres    false    226            �           2606    25101    compagniadinavigazione sitoweb 
   CONSTRAINT     \   ALTER TABLE ONLY public.compagniadinavigazione
    ADD CONSTRAINT sitoweb UNIQUE (sitoweb);
 H   ALTER TABLE ONLY public.compagniadinavigazione DROP CONSTRAINT sitoweb;
       public            postgres    false    217            �           2606    25103    compagniadinavigazione telefono 
   CONSTRAINT     ^   ALTER TABLE ONLY public.compagniadinavigazione
    ADD CONSTRAINT telefono UNIQUE (telefono);
 I   ALTER TABLE ONLY public.compagniadinavigazione DROP CONSTRAINT telefono;
       public            postgres    false    217            �           2606    25105    tratta tratta_pkey 
   CONSTRAINT     V   ALTER TABLE ONLY public.tratta
    ADD CONSTRAINT tratta_pkey PRIMARY KEY (idtratta);
 <   ALTER TABLE ONLY public.tratta DROP CONSTRAINT tratta_pkey;
       public            postgres    false    228            �           2620    25106 &   prenotazione after_insert_prenotazione    TRIGGER     �   CREATE TRIGGER after_insert_prenotazione AFTER INSERT ON public.prenotazione FOR EACH ROW EXECUTE FUNCTION public.after_insert_prenotazione();
 ?   DROP TRIGGER after_insert_prenotazione ON public.prenotazione;
       public          postgres    false    226    241            �           2620    25107    tratta aggiungi_navigazione    TRIGGER        CREATE TRIGGER aggiungi_navigazione AFTER INSERT ON public.tratta FOR EACH ROW EXECUTE FUNCTION public.aggiungi_navigazione();
 4   DROP TRIGGER aggiungi_navigazione ON public.tratta;
       public          postgres    false    242    228            �           2620    25108 %   prenotazione diminuisci_disponibilita    TRIGGER     �   CREATE TRIGGER diminuisci_disponibilita AFTER INSERT ON public.prenotazione FOR EACH ROW EXECUTE FUNCTION public.diminuisci_disponibilita();
 >   DROP TRIGGER diminuisci_disponibilita ON public.prenotazione;
       public          postgres    false    226    243            �           2620    25109 !   prenotazione elimina_prenotazione    TRIGGER     �   CREATE TRIGGER elimina_prenotazione AFTER DELETE ON public.prenotazione FOR EACH ROW EXECUTE FUNCTION public.elimina_prenotazione();
 :   DROP TRIGGER elimina_prenotazione ON public.prenotazione;
       public          postgres    false    244    226            �           2620    25110    corsa imposta_disponibilita    TRIGGER     �   CREATE TRIGGER imposta_disponibilita AFTER INSERT ON public.corsa FOR EACH ROW EXECUTE FUNCTION public.imposta_disponibilita();
 4   DROP TRIGGER imposta_disponibilita ON public.corsa;
       public          postgres    false    219    245            �           2620    25111 !   natante incrementa_numero_natanti    TRIGGER     �   CREATE TRIGGER incrementa_numero_natanti AFTER INSERT ON public.natante FOR EACH ROW EXECUTE FUNCTION public.incrementa_numero_natanti();
 :   DROP TRIGGER incrementa_numero_natanti ON public.natante;
       public          postgres    false    222    229            �           2620    25112    tratta insert_into_corsa    TRIGGER     y   CREATE TRIGGER insert_into_corsa AFTER INSERT ON public.tratta FOR EACH ROW EXECUTE FUNCTION public.insert_into_corsa();
 1   DROP TRIGGER insert_into_corsa ON public.tratta;
       public          postgres    false    250    228            �           2620    25113    corsa modifica_ritardo    TRIGGER     �   CREATE TRIGGER modifica_ritardo AFTER UPDATE OF ritardo ON public.corsa FOR EACH ROW EXECUTE FUNCTION public.modifica_ritardo();
 /   DROP TRIGGER modifica_ritardo ON public.corsa;
       public          postgres    false    246    219    219            �           2620    25114    prenotazione prezzo_bagaglio    TRIGGER     |   CREATE TRIGGER prezzo_bagaglio BEFORE INSERT ON public.prenotazione FOR EACH ROW EXECUTE FUNCTION public.prezzo_bagaglio();
 5   DROP TRIGGER prezzo_bagaglio ON public.prenotazione;
       public          postgres    false    226    247            �           2620    25115 +   prenotazione setta_sovrapprezzoprenotazione    TRIGGER     �   CREATE TRIGGER setta_sovrapprezzoprenotazione BEFORE INSERT ON public.prenotazione FOR EACH ROW EXECUTE FUNCTION public.setta_sovrapprezzoprenotazione();
 D   DROP TRIGGER setta_sovrapprezzoprenotazione ON public.prenotazione;
       public          postgres    false    226    248            �           2620    25116 (   prenotazione verifica_disponibilita_auto    TRIGGER     �   CREATE TRIGGER verifica_disponibilita_auto AFTER INSERT ON public.prenotazione FOR EACH ROW EXECUTE FUNCTION public.verifica_disponibilita_auto();
 A   DROP TRIGGER verifica_disponibilita_auto ON public.prenotazione;
       public          postgres    false    226    249            �           2606    25117    prenotazione idcorsa    FK CONSTRAINT     x   ALTER TABLE ONLY public.prenotazione
    ADD CONSTRAINT idcorsa FOREIGN KEY (idcorsa) REFERENCES public.corsa(idcorsa);
 >   ALTER TABLE ONLY public.prenotazione DROP CONSTRAINT idcorsa;
       public          postgres    false    3255    219    226            �           2606    25122    bigliettointero idpasseggero    FK CONSTRAINT     �   ALTER TABLE ONLY public.bigliettointero
    ADD CONSTRAINT idpasseggero FOREIGN KEY (idpasseggero) REFERENCES public.passeggero(idpasseggero);
 F   ALTER TABLE ONLY public.bigliettointero DROP CONSTRAINT idpasseggero;
       public          postgres    false    214    3263    225            �           2606    25127    bigliettoridotto idpasseggero    FK CONSTRAINT     �   ALTER TABLE ONLY public.bigliettoridotto
    ADD CONSTRAINT idpasseggero FOREIGN KEY (idpasseggero) REFERENCES public.passeggero(idpasseggero);
 G   ALTER TABLE ONLY public.bigliettoridotto DROP CONSTRAINT idpasseggero;
       public          postgres    false    215    225    3263            �           2606    25132    corsa idtratta    FK CONSTRAINT     u   ALTER TABLE ONLY public.corsa
    ADD CONSTRAINT idtratta FOREIGN KEY (idtratta) REFERENCES public.tratta(idtratta);
 8   ALTER TABLE ONLY public.corsa DROP CONSTRAINT idtratta;
       public          postgres    false    228    219    3267            �           2606    25137 2   indirizzosocial indirizzosocial_nomecompagnia_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.indirizzosocial
    ADD CONSTRAINT indirizzosocial_nomecompagnia_fkey FOREIGN KEY (nomecompagnia) REFERENCES public.compagniadinavigazione(nomecompagnia);
 \   ALTER TABLE ONLY public.indirizzosocial DROP CONSTRAINT indirizzosocial_nomecompagnia_fkey;
       public          postgres    false    221    3247    217            �           2606    25142 "   natante natante_nomecompagnia_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.natante
    ADD CONSTRAINT natante_nomecompagnia_fkey FOREIGN KEY (nomecompagnia) REFERENCES public.compagniadinavigazione(nomecompagnia);
 L   ALTER TABLE ONLY public.natante DROP CONSTRAINT natante_nomecompagnia_fkey;
       public          postgres    false    3247    217    222            �           2606    25147 '   navigazione navigazione_codnatante_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.navigazione
    ADD CONSTRAINT navigazione_codnatante_fkey FOREIGN KEY (codnatante) REFERENCES public.natante(codnatante);
 Q   ALTER TABLE ONLY public.navigazione DROP CONSTRAINT navigazione_codnatante_fkey;
       public          postgres    false    223    222    3259            �           2606    25152 %   navigazione navigazione_idtratta_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.navigazione
    ADD CONSTRAINT navigazione_idtratta_fkey FOREIGN KEY (idtratta) REFERENCES public.tratta(idtratta);
 O   ALTER TABLE ONLY public.navigazione DROP CONSTRAINT navigazione_idtratta_fkey;
       public          postgres    false    228    3267    223            �           2606    25157 +   prenotazione prenotazione_idpasseggero_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.prenotazione
    ADD CONSTRAINT prenotazione_idpasseggero_fkey FOREIGN KEY (idpasseggero) REFERENCES public.passeggero(idpasseggero);
 U   ALTER TABLE ONLY public.prenotazione DROP CONSTRAINT prenotazione_idpasseggero_fkey;
       public          postgres    false    226    225    3263            �           2606    25162 )   tratta tratta_nomecadenzagiornaliera_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.tratta
    ADD CONSTRAINT tratta_nomecadenzagiornaliera_fkey FOREIGN KEY (nomecadenzagiornaliera) REFERENCES public.cadenzagiornaliera(nomecadenzagiornaliera);
 S   ALTER TABLE ONLY public.tratta DROP CONSTRAINT tratta_nomecadenzagiornaliera_fkey;
       public          postgres    false    3245    216    228            �           2606    25167     tratta tratta_nomecompagnia_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.tratta
    ADD CONSTRAINT tratta_nomecompagnia_fkey FOREIGN KEY (nomecompagnia) REFERENCES public.compagniadinavigazione(nomecompagnia);
 J   ALTER TABLE ONLY public.tratta DROP CONSTRAINT tratta_nomecompagnia_fkey;
       public          postgres    false    228    217    3247            h   �  x�}X�nܸ\��B���8$������ ���݊M\���3�%R���N�:�:U%)����Of�#�M��]��°���+�D�*ſ��2��~C]\H)*&�����g���g���5Ri7�i��&E�u�R�b+�S���e�Y"���f]yN���ak�4��Ϙ�}h[\m*��qf�_�0W̎T��a�k�6À�(�	c��b7ݶ�b_n��i�f�D���|�s���o�[H�*��ts$������ d+���7Էa��m���*)J=7�jhB��ulRVJVң�S�Ƅ��~�m:,*φ%��;OI�3����e�{ź���|ꇟq@�a�w�Ѕ�3�6�ι�9$Xf�<rK�\�["��q�u)҅v�`Z_�)����u~�� &�),]�X�&�ΐa,1�+�a@R���}ף��~��~���"!Љ~`��A���T��;n� �U�>a?D)�mF�����ާ9c̄09��.6CBI��+�r3σF[OyDwmح��i�IU,�д�=F���1.�i�ɿ�����u�����o"�b�"i���<2^`	�A�a�.����i'NW��i��#�zv�g�<�����6m�!J0��sJ|�`dk��[��׊I��`��ʖ�K�+��_��؍c�\�����qⴔ���!kQtY�	�ɡY�!Xg�W�R�d)	l�o�w�ς P�=(��>�]�I��� no�d�k	���x������8����oh#z���lO�V��Z_S�������61b��x�.����h��;0bTyi��5�Pvn�H��-�qڊ,P�Q�H3�z�-�t�9 &�d��z�����rz�=��Zk[�;�B��K���.��,
�醈?5mۼ��W�ϊ~��Ȟu>|���"̅��h:�g�Ghbӏ������&7D��:s���7[ ��[h�N��;���vC��r�בVY���i���I��U��'c9i��e�b�.Y�H~���	��_'�vB-H�6a;$�R�2�M���2����0n/:ea�2#=�n5�rL��0��,��<�/�i����
�.6�W��B�j��`;}M���*�>�X�M�O=�Gܧ�(Z������5�� �!L\���!�/Κ�#����z6#��N�ݶ���l��M���;� *��j�w;x ��r�/�x��	��~���K�C'��;s&w�#J]�a؛1[K�I�����NΨD�t��ڴ��d�'�5�i#��y)<kLe��e�GDkl�<��\fKo�Mr��>�hX]$D��Ų�ᒰ+g�૤f���^�5�J��ZX뜕����7��nO�{b,������ۭ���/Nx%
�]1��_�{��+����������xx�Z� ��ϕ��ט'��CS�~�\2�`1�}��	��8��?%ȸå����_�(|nx�I�
'��E���g���~�U�LZ�jԇ���ZRk�s7jRE�;�ñy%B��&WĜ\�*�y��9i�����h����`�Dֳ.z��r1���l�@
���|�(	q��>��;X�P?9��7�RO�)���n��{��*UM�8��w)R27�{���>k�瑗˺��^g��'+;��Raȍ.�x��,R$�0��y��]m�K���ݽ�4�IХ�xq��g�iSGٔ��`�=��Y6ayq3�ڶ"���J	S^"��M�)��.�R T�vE9����g&�>]yWp9����w0(hb<[XdTP	�������� �2}'Io�v:]�&7V�X�ד��g�0�V�1���h��̮.�,F�Ȩ�ו��OO� (��ۅۑ���x
�w�%�_6XU�v��&�\���*^�"���[��b�X3�8Q������������cuD�ZE�������e��Kӏ���A�� }2b�W#!u�8��i��TUտ�x+      i   �   x�}��N1���)�U'N2Vm�B%D%&�)�],��>=�;6��?�?�s	^9�E����zo��̹�r>�Xr(E�o�D<�9�To�����1� ��OC���G�h�6��#��/E�h���~����<�H�ULBH6������:U2���j�c�O/�h�*����Ķ��F]�ƕ��9Vs!1�&9�[z���\��>f������~l;��v�ʟ��3^wZ�/�mn�      j   �  x���ێ�0�����0��,�
�қI�R��9&�x��O	Tڊ���H������p	\T2�/��j8u�ب\o�+�<|*!r`p��=�?5����0`j�j@H��� �j��%�ю��+��D��:㠜���i��4���/e�L�%��
��-H��$��r�;6��)(���I�%�2�QA����A����>v�,m���{��Pj��ln�h@��!\��ԋ�h�V���]���z�����Z�[��Щ�Ե�d����\(?�c�Z�5dj��՗kDx������֓�ŵg�k#�k��^U���;���ɩ�Ys������7�A�M^�iig��GJGm����$��Jhn$>ظ�����ۖ$�w�u����j���TN��n=P���&�+�\��rB>������;Jh��c}wу^l8��6��3�����wu�!L�`S^Jy����R�%�M6���7��^�M�|���[��v      k   �   x�]�K�0�ϛ��<n-�CM/=zYTڀ&E���"�ag��q���{L�4����"�댽G(�q!�Ric!��->5q�<�|�r�gr�9�{������R
bhq'�~�Vց��zyL�c�s!�����͇�?�zRSB���GZ      m      x�u]K�-7��وGա?�M�
z��o��岀;sNJ� bf������u�W+m|��]�W�̦�,�����D�����b��@��^��g�7T�.Ӟh���,}b�c����O�~��+�UX�e|��\8x���l�����+�o��}磡&�u�P�|7_�z�8�����+_d���C T�uԲ�Y-��UX� k�$�r T:F-�|k}Ű|����X_1,ߏZ�=_�n�=R�?v}�g���3���>�����Y Ѣ�UJ&R�/%�H�8���{~�`Jԕ/&8|�મ\ǐgQ��1^��D�}�$��7Q�s^�lǕ�A�����W�ƈ���:wR�պ�??J�{N7���@����U����,��w��b�B��3wǯ֥=�%�|����������ӕ7�XN���.]GO�%�՛�^YY��QF1^�g��gi
����9����.��31j���F!�\��T�d�\u�J����z�,�~��;�(��s��d�ퟍq.����8�߻�w"c���H�JKyCme�>Rߓ ~x�M�.57K���3"q�*j�O�7XڿB�/�[u��^��&��7�o=�
�I|����ݎ���Vs�ڛďz �f���^��ݣ�[��@<vD�jXV��#yS��;�����]X�����ı�,G�	���SV������>!QX��m$�F䙣��F���7׈��^ѭ�P��v�R7�a���W�;�I��ݝ���ǒ㥱���Æl\���n����hk/�Wv>ƻvq'P�K�Ֆ��r;pM���uݼCh*,���>�<�����Jɥq�ԯ�t��8�/�˭}ݸ#EI��f�R�9�zpG����Jܝ�y7��Н��Z��rq�՜���*><�Q˨:<�c���}�uW����9X�۲�$[���q�}W_�[Vd����cٷ9?��	1�����G��njC���os��@�?�/&�{��u+�� �z^�����m���[!��6�0��!�����z/BUzj��\a7]��ᯚc�g�E���{�Dy�¶ߊ���d��d��:�w[m��؉�۳��z�Itb��$�
-�:z��c�����d�K�ĊW}xZ�ux�x��&z#���I�1h��c����maYsǶ����h����&�$Xi���L��@jtL<۳~+�!h0j.Pi����T�=��J���F@Z�uLn�sx��
h0j�_Ga��Ru��h0Z���]Gaf�kro����L��[z�u��F��BϽ��[z�u�޶�:
=���b�)�Q�i�=�zw��Xz�ufSڶ�;=�����������+��	hª�����bm7�&()��ԁ�	+�N��
�\Ҵ�5�����j����f�z9m#�}P���q��6�q��lv*�մͤl�m�m�K^B6�����]�BLw�:��s�k�\E)�lX�F!���(��6��bw�����+Ĵ�< ��M
1�\4`/Ȇ]bڨb�F��v5��ײ���i�D6��6�1��	�A�MhlT�46*ӆ��+m�x@�W�W��Vz�5z+�F7z+K������'ؘ6��W�w!۔Ʋ��ޘ6��Fo6�acڰC�ˢ���|�/�Qw�Kf��%w�E-G�N͓�L�2mX���ƉCD^�8D�g��F��CD�'i�[Z�O'�sK�
1m�%+Ĵq����� �E��b�*J!Za�ALwbY�x@Za- i'XZV�i�S!Za= ���i�z@Zam�ȍ�ҲB,��/r�������_��biY!Za�^r7���z	z����X�����^bRw�K��z���|!�E--+D+�$^�ҲBL���x���x���x���x���x���xQ�%/*�d�E%�L��Ē�ݑ��ݑ��ݑ��ݑ��=q��=q��=q��=q��=q�����/D+l5���1m�%+D+l3���=�
{����B�xQK�
�,Z�A��z@Za= }S#�
�i�����i��
��5������� Za�A��|���%^T�^�E%�%^T�^�Ew�K��z��A/�;�%^�ҲB,�H+��������� ^t�!ċ.?D�x���x���xQ�%/*�d�E%�L��Ē�ݞ���s� ^t{�ċn�Q�x���x���x���x���x��(ߌN����S?X ܉+ �����x�@�P� p'�@E���^�(��j �& �4(+���Wn_��rAD�b��r ��Q$�)�F�#�˽!�7����h��& ��Q���q�pp٩y9pvA����:�(;�3����a�����P��i8BO�����S#��9"�8E~�ď�-�_�Lg~������l�c�a�o����LW��`�ql柋)����)&S�(���'b�!/�-���bu�0��
�aȋU^Ð+��!/V{C^��FKl7�7z��eE_�cPW�{���Dש�c;�Cߞ�sP?�-yu
�b����]�~s�vwb.t�1���sA���Fy����c���Iy����1����0��?{7������FԿf7��R}.hE��qÐ�ڝhF�km�(/��1�/0��^Z�8ғ\�%�D���\Д��N�1^B�hK�+�/%b2^⼣3�oUC^j����ŊbԜ�>Pw����?]1����b>O�*�1O�K�	�֚y��f���i��'&�f������:��m�"�o6E^�:l����u��Y���y]��y+���i�V������E�kܧ�C�׹wӆ"/�N�"�A�h�A�hȁ�1E^f2�^f2���`t��dT^z2*/�Ε"�A�h����4�y9�ɨ �� �(��3�b���g^��SeO1�O�?Ř?UC�>S1�a�3c�T���M�П��Tyq����cR�U����\�>S1��}�b̟����i��;ȋ�yC^��c�K�=:L/��\��ǐ�����H�}�_�*L/��U�k���X��0��1�^�ty9q�VE^N��U��glU�?c�2��[#���E�3�YJ�7�X3Ő7�X7Ő7�vcX̭��E�VeWR_|֍ԗ�FjlD#�%����4Rc��F�s�H}�`��|u�Nj�8�r�,W)�r�,S)�r�,O)�r�,K)�r �h9�d��H2�_$�/������/;5:^vjt����x98�y98��y98��y9���"/~�W{�ݹ�/�2�"/��"�&m���w�fO����^�=�~��z�o�T/�͑��9R��7G���L��ߜ�^�3�~s�z�����\�^�+�~s�z�o�T/�MIF�oJ2
~S�Q𛒌�ߔ�(�͝��S��r�S��r�S����d-�/'k�~98YK����Z�Im�hXC;��ƈFj���~9h����1=�6:��F��!�O��!�1������3����R��C���!�OS�R�#/32���%����Hm�h/+�R�#�6VG�6:�RHm4F�����*�FרTR#��͑����'�O<��|��&�O�7��"�	���M�'��o>�E~��=4*�{hT�'��(�Ğ��S��Gj|�H��O�Q��#5
>q�F�'��(�ę�8S��Wj|�J��O\�Q��+5
>q�F�'J2
>Q�Q�����O�d|�N��OܩQ��;5
>q�F�'��>�D���'*��O<Q1|≊!�zh��Q�Ol���-�>�'��{2
>�'��/��ؓQҗFY_2��{cD#��9`}I��%]��g�Q��3�(�ĕ�|���>qe~��2��O\���'J2
>Q�Q�����O�d|�N��OܩQ��;5
>q�F�'��o�O�7��'��ē�|���F:���9!H��(�%��(�%��(�%��(��6��(��6��(��6��(���a+���a,+��xo�|6�@zwG1���;�!/��Qy��bȋwyC^�ϣ��FL֙��vf#&����mҁ��z��כt %�&HI�+��:וvf#&�   �FLڙ���3��Wig�c6ڙ���vf=f��Y߿�:����!/�Ry�~�bȋw�C^�'���]!Ő�����KO�w䥧�;��S�y������|G^Fj�#/#5ߑ������L�w�e���2S�y����ވ���R�yY�������`oĂ끼Hr=�I��"��d�%t=����D^v�z"/;u=������X���ˉ:�'�r��퉼��c{�:�1�ӡ�E��\�N�&��Rg����z�:��,Z�c�KO�����i�)�N�B��"�N;/��t�rau:r��:�gE����\�ԈI�tĤu�c�7�?�wI��wI������q�����&o�wꚾq]�7�k��=tM����I����I߸G��o�#��2��2��2��2��S������!~����=t}�����C��]�wG���;Bׇ���>�����!~w���3t}�ߝ��C��
]�wW����Bׇ���>����!~W�k�w%�&~W�k�w%�&~w���;t�Cٯ��T�>DxF�m����է�C����8�!��n?��+�u�%��E��W�w�|�!�\#�S���~���-���"'f���+���jK&.��������2[2��=�q�=
��D݇���M!���~���s5Kއ�qC?B����}5�~��#�q��!�G��j�!�]|W�`FkpT�w�����(n��7��C�^L��{������ubey"׉��Q�P���f7 �gHH���Bve��dv 	48*�&7��@n&;�C����}�O�i�?}�v�Q��C��M��+���䷛�-�\rNMr�9Q4;)*:��П�{Ӏ����?p���7���e6���N2��X}���i�����s�w9��kx����ރ��s��@���\�=��:x��s�w��W:`��g+��'Yy���$?Qj���Cm�?ׇߔ�/j����.�u�F��%Kc��~s�K?������?���d鏍��_�����      o   \   x�M�1
� ��w�N����jq?���D<�Cm����SAprNvAPj+z$]�o��!��>���-�^�����RD�������)-      p   �   x�}�1� ���1Ziu4����8�\-I� �?_Ф��0��;'�t�~Y����g�`mf��W���V���w�Fp�u�|�!a$O'���D��&�$P~7%�������5B��&�ى�?��V�{��.���1��]q      q   D   x���	�0 ��TL��v/鿎X��@���&p�#�+�p�)�~s�i��a�����m��s�}l��m      s     x���Ko�6��䯘]W*H��e���IL�ꆶ5QYd9E��{�d;���&y�~^<�a�ķ��G����.t%�%��u���ּ/TS�Rj%�� ��a-��P��Jj-��g�}�3�B���R�R��C�q�3u�p���wnj�8�[\�9[h]h'�W�fh��I=ot�Ц0F�Rcė�ut�G4�Å���q��'�:�|�*�.Bu�sצ>Aܧ�*>�:��s�:M7�v.�Ԉ��K=E���ז���F!�1�1����U�m����%J�Ф��)�D�������Ko�1�}z=.��I�8��5e\jiJ�#tm�9߄��*;�n�4V|�>�]�n����.���݇�S���F�Z܅¾	/�|)�cSK�n������S%�s��Q�ql7 �T�(�d�1.{�C�4T]h�T��y���?bׅ�"5��R��p���1d]B	���q��v��G�Z��qǜ,�,� �@�aXŖ��#����il�.��>dY��PKY��6�(]+�^l*R�Ҳ���j�t�C�v������t�>�����<�;�D#*�b���p�@Ԕ����I��6M��T�*Sѿ��V���di5u��Kk��fCFֈ�.6h��~?w�xiK�%�ї�́b�*i휦���jG*��S���Xy��g6G����v��g�1�J�� -��׎�����<� yx��1g�P씣buac�zc�?�;��Z%++5N�Z�9��d:jXI//����B��=���������=0HZV%�=)iÖ��5����=MivO�����du2��?�J�Dگ����K���r�3��S��3��\���?�쟵z1�g�g�����d���G���}��}�u���^�g>�������1MDT/�gΆ��v�9W]���}�%�}�ͥ}��a�N-�g���������}:��>�.�OW��ϣV�t�f1�ȯ}���v���;���f�$m�`+���0�?Xd��O���D6�v�Y}pIWaꇟ��$�8�{��Y-���]�9�̞ިI��Q}�m|�lfǂ�����6N���nל������%��i8y���Y7��*��7'w�	��
��,���|���v�o��}u&��D����y/���l:h�I���h������9x7	�Qs���Q��}��#�Yݍ��`�rz �" 46;�%4'ǻ ��>M��~U��� ��Ly~¼l�`i����2V �f���R���:!��z��f�8b��"�2��w�����U	l��ڙh����e��HZ�^�%z��T�A+7�����?*&]�VM������N��#��i�#4�~v��$�A�7xz�%4�~~}/`B��Wi	&��Au&4�~�������Ea�(�n�)4 ?+v*���[�
���Ѐ��È�W!�X�sA�H�=��/�[�n�K��Y@�`����l"�����-�E+̤.q���$<�X����%�����!�ɜ�����C���:��R�\�1      t     x�]�I�1D��a~����u���'CV}��q! At?�^��ƺ�����:*]�]��_�.&aׯ6^����4�k�h9���׼FG�;���;���=������K��������a�"��bݢ��[�����Ĺ߿μe�͎��J0�o0��'o������@�3�����>o�w�+lm�ν�Vg��o�gOj���F�H�.����~2[����(�k_���[d��Mf_��k�Uo�|�![/k7����𼰳�/*#�h7���M�3t�F����!cs�,��>���dO�'&�lo��3����2ѾV�-�tҽM��,���wح��>�4�$мN�Yt����e�fO�#�n It��k����a(Te������l���ZO���bF�9��Jʢ�S�����J�p8���dPL�r���G��bYi�e�Lp����-�~|P�J���7�ɤ�쓖�m(м3�E?Av��e��	C?4��L=a� )`S�@���r˦'��o���a��EO�hE0{�i3K�)����r���/�-���ڼF-����Џ��7>gY�cr����~��	=o^�3�PK��a����x�
����/L҃�����J�!cmm�
Z�8C&�,��]`'��28中����;��7&8D��*��$�f�A�� <�(:=��x�Rt`�6��3���n��(Zޛ�n�������@���M�s�0ԶE�s���3#��o��o�߄+��~�$>���t�*C�k�_�VЃ�-�7��G~�KM�"k����7bܾ,?���>Ao"��Sº�*��:��P68/ȡW���F{�����Ȁ zD�G�Na���1k�
kDY��U�X���{����^�@��M=HA]w�^������Yq/u��w���Gj��O乳��J ���p���Y��8C��rS�z���Z;���R�r=�|��@8ڋ���.Z0��]S-z������I����.��ݹ_9˯6����1ieb�u̮h�)V_7�}X�\�|w�bao���;���_f�ne͝Śϝ��$���������I����-����E���YxuO?��
�5y��U�:?p�:T�����b�(j��'�k}rE���tu����3���Tc�;���
�L5QzrdG��ғ���C�~\�_�D��b	;���Z��7�Rzr=x�M�����9�!FO��`K�~\Yy;��#"� ��+�      v      x���͎�0���)x�C&�t)�Z"%�E4��L����U���
�,�a�ϗs�C>���� �nGz���pP2A9T�����~��;%�L�gV7�0ws��:�Ӕ&$|�%(�����L�,� ��7Z���e�qp�xWP���Ps��\��=�ѣ�������p*)��Ng��׭v�2��^;S=���㐢=��d酀JWzL����Qc���1�>�4��8	�2��L4�a������٣n���kH������!�;y-~W�յn�G�A�:�s��4-.Zs�м;{H�ز&Λ�q�[�)��`g� x�t�?Vj��
�.�fo���E���5����x�}��t~��(��6��̉n%�׋酒9?�r����h��Z�(,v1�����n�Y�������k�鴳S��+���%S]��fAO���K�x7�"�l���{�3��FL���X�,�p���de��ˠ�A3�mA?�-��'�q� ���j     