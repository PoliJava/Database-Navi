PGDMP     )                    |            progetto    15.5    15.5 N    k           0    0    ENCODING    ENCODING        SET client_encoding = 'UTF8';
                      false            l           0    0 
   STDSTRINGS 
   STDSTRINGS     (   SET standard_conforming_strings = 'on';
                      false            m           0    0 
   SEARCHPATH 
   SEARCHPATH     8   SELECT pg_catalog.set_config('search_path', '', false);
                      false            n           1262    24732    progetto    DATABASE     {   CREATE DATABASE progetto WITH TEMPLATE = template0 ENCODING = 'UTF8' LOCALE_PROVIDER = libc LOCALE = 'Italian_Italy.1252';
    DROP DATABASE progetto;
                postgres    false            �            1255    24733    after_insert_prenotazione()    FUNCTION     X  CREATE FUNCTION public.after_insert_prenotazione() RETURNS trigger
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
       public          postgres    false            o           0    0 $   FUNCTION after_insert_prenotazione()    COMMENT     �  COMMENT ON FUNCTION public.after_insert_prenotazione() IS '-- funzione che, dopo l''inserimento di una tupla in prenotazione, attiva il trigger che permette di aggiungere una tupla corrispondente in bigliettoridotto se l''età è minore di 18, oppure in bigliettointero se l''età è maggiore di 18. Questa funzione inoltre permette di indicare l''eventuale sovrapprezzo della prenotazione o il sovrapprezzo dei bagagli, e di diminuire la disponibilità nella tabella corsa';
          public          postgres    false    248            �            1255    24734    aggiungi_navigazione()    FUNCTION     �  CREATE FUNCTION public.aggiungi_navigazione() RETURNS trigger
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
 -   DROP FUNCTION public.aggiungi_navigazione();
       public          postgres    false            �            1255    24735    diminuisci_disponibilita()    FUNCTION     �   CREATE FUNCTION public.diminuisci_disponibilita() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
	
	UPDATE corsa
    SET disponibilita = disponibilita - 1
    WHERE idcorsa = NEW.idcorsa;

    RETURN NEW;
		
end;
$$;
 1   DROP FUNCTION public.diminuisci_disponibilita();
       public          postgres    false            �            1255    24736    diminuisci_disponibilita_auto()    FUNCTION     v  CREATE FUNCTION public.diminuisci_disponibilita_auto() RETURNS trigger
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
 6   DROP FUNCTION public.diminuisci_disponibilita_auto();
       public          postgres    false            �            1255    24737    elimina_prenotazione()    FUNCTION     �  CREATE FUNCTION public.elimina_prenotazione() RETURNS trigger
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
 -   DROP FUNCTION public.elimina_prenotazione();
       public          postgres    false            �            1255    24738    imposta_disponibilita()    FUNCTION     �  CREATE FUNCTION public.imposta_disponibilita() RETURNS trigger
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
 .   DROP FUNCTION public.imposta_disponibilita();
       public          postgres    false            �            1255    24739    incrementa_id_passeggero()    FUNCTION     �   CREATE FUNCTION public.incrementa_id_passeggero() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
 
begin

	new.idpasseggero = nextval('sequenza_id_passeggero'); --funzione che restituisce il prossimo elemento nella sequenza
	return new;
	
end;
$$;
 1   DROP FUNCTION public.incrementa_id_passeggero();
       public          postgres    false            �            1255    24740    incrementa_numero_natanti()    FUNCTION     �   CREATE FUNCTION public.incrementa_numero_natanti() RETURNS trigger
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
       public          postgres    false            �            1255    24741    modifica_ritardo()    FUNCTION     �  CREATE FUNCTION public.modifica_ritardo() RETURNS trigger
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
 )   DROP FUNCTION public.modifica_ritardo();
       public          postgres    false            �            1255    24742    prezzo_bagaglio()    FUNCTION     j  CREATE FUNCTION public.prezzo_bagaglio() RETURNS trigger
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
       public          postgres    false            �            1255    24744     setta_sovrapprezzoprenotazione()    FUNCTION     �  CREATE FUNCTION public.setta_sovrapprezzoprenotazione() RETURNS trigger
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
 7   DROP FUNCTION public.setta_sovrapprezzoprenotazione();
       public          postgres    false            �            1255    24745    verifica_disponibilita_auto()    FUNCTION     �  CREATE FUNCTION public.verifica_disponibilita_auto() RETURNS trigger
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
$$;
 4   DROP FUNCTION public.verifica_disponibilita_auto();
       public          postgres    false            �            1259    24746    bigliettointero    TABLE     �   CREATE TABLE public.bigliettointero (
    codbigliettoi integer NOT NULL,
    prezzo double precision DEFAULT 15.50,
    nominativo character varying(100) NOT NULL,
    idpasseggero integer
);
 #   DROP TABLE public.bigliettointero;
       public         heap    postgres    false            �            1259    24750    bigliettoridotto    TABLE     �   CREATE TABLE public.bigliettoridotto (
    codbigliettor integer NOT NULL,
    prezzo double precision DEFAULT 10.50,
    nominativo character varying(100) NOT NULL,
    idpasseggero integer
);
 $   DROP TABLE public.bigliettoridotto;
       public         heap    postgres    false            �            1259    24754    cadenzagiornaliera    TABLE     u  CREATE TABLE public.cadenzagiornaliera (
    datainizio date NOT NULL,
    datafine date NOT NULL,
    giornosettimanale character varying(70) NOT NULL,
    orariopartenza time without time zone NOT NULL,
    orarioarrivo time without time zone NOT NULL,
    nomecadenzagiornaliera character varying(100) NOT NULL,
    CONSTRAINT ck_date CHECK ((datainizio < datafine))
);
 &   DROP TABLE public.cadenzagiornaliera;
       public         heap    postgres    false            �            1259    24758    compagniadinavigazione    TABLE     �   CREATE TABLE public.compagniadinavigazione (
    nomecompagnia character varying(50) NOT NULL,
    numeronatanti integer DEFAULT 0,
    telefono character varying(15),
    mail character varying(50),
    sitoweb character varying(50)
);
 *   DROP TABLE public.compagniadinavigazione;
       public         heap    postgres    false            �            1259    24762    corsa    TABLE     �  CREATE TABLE public.corsa (
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
    DROP TABLE public.corsa;
       public         heap    postgres    false            �            1259    24765    indirizzosocial    TABLE        CREATE TABLE public.indirizzosocial (
    indirizzo character varying(50) NOT NULL,
    nomecompagnia character varying(50)
);
 #   DROP TABLE public.indirizzosocial;
       public         heap    postgres    false            �            1259    24768    natante    TABLE     
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
       public         heap    postgres    false            �            1259    24773    navigazione    TABLE        CREATE TABLE public.navigazione (
    idcorsa character varying(15) NOT NULL,
    codnatante character varying(15) NOT NULL
);
    DROP TABLE public.navigazione;
       public         heap    postgres    false            �            1259    24776 
   passeggero    TABLE     �   CREATE TABLE public.passeggero (
    idpasseggero integer NOT NULL,
    nome character varying(50) NOT NULL,
    cognome character varying(50) NOT NULL,
    datanascita date NOT NULL
);
    DROP TABLE public.passeggero;
       public         heap    postgres    false            �            1259    24779    prenotazione    TABLE     C  CREATE TABLE public.prenotazione (
    idcorsa character varying(15) NOT NULL,
    idpasseggero integer NOT NULL,
    sovrapprezzoprenotazione double precision DEFAULT 3.00,
    sovrapprezzobagagli double precision,
    idprenotazione integer NOT NULL,
    peso_bagaglio double precision,
    auto boolean DEFAULT false
);
     DROP TABLE public.prenotazione;
       public         heap    postgres    false            �            1259    24784    prenotazione_idprenotazione_seq    SEQUENCE     �   CREATE SEQUENCE public.prenotazione_idprenotazione_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 6   DROP SEQUENCE public.prenotazione_idprenotazione_seq;
       public          postgres    false    223            p           0    0    prenotazione_idprenotazione_seq    SEQUENCE OWNED BY     c   ALTER SEQUENCE public.prenotazione_idprenotazione_seq OWNED BY public.prenotazione.idprenotazione;
          public          postgres    false    224            �            1259    24785    sequenza_id_passeggero    SEQUENCE        CREATE SEQUENCE public.sequenza_id_passeggero
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 -   DROP SEQUENCE public.sequenza_id_passeggero;
       public          postgres    false            �           2604    24786    prenotazione idprenotazione    DEFAULT     �   ALTER TABLE ONLY public.prenotazione ALTER COLUMN idprenotazione SET DEFAULT nextval('public.prenotazione_idprenotazione_seq'::regclass);
 J   ALTER TABLE public.prenotazione ALTER COLUMN idprenotazione DROP DEFAULT;
       public          postgres    false    224    223            ]          0    24746    bigliettointero 
   TABLE DATA           Z   COPY public.bigliettointero (codbigliettoi, prezzo, nominativo, idpasseggero) FROM stdin;
    public          postgres    false    214   �       ^          0    24750    bigliettoridotto 
   TABLE DATA           [   COPY public.bigliettoridotto (codbigliettor, prezzo, nominativo, idpasseggero) FROM stdin;
    public          postgres    false    215   %�       _          0    24754    cadenzagiornaliera 
   TABLE DATA           �   COPY public.cadenzagiornaliera (datainizio, datafine, giornosettimanale, orariopartenza, orarioarrivo, nomecadenzagiornaliera) FROM stdin;
    public          postgres    false    216   6�       `          0    24758    compagniadinavigazione 
   TABLE DATA           g   COPY public.compagniadinavigazione (nomecompagnia, numeronatanti, telefono, mail, sitoweb) FROM stdin;
    public          postgres    false    217   2�       a          0    24762    corsa 
   TABLE DATA           �   COPY public.corsa (idcorsa, nomecompagnia, cittapartenza, cittaarrivo, scalo, ritardo, disponibilita, nomecadenzagiornaliera, disponibilitaauto) FROM stdin;
    public          postgres    false    218   ٘       b          0    24765    indirizzosocial 
   TABLE DATA           C   COPY public.indirizzosocial (indirizzo, nomecompagnia) FROM stdin;
    public          postgres    false    219   ;�       c          0    24768    natante 
   TABLE DATA           p   COPY public.natante (codnatante, nomecompagnia, tiponatante, capienzapasseggeri, capienzaautomezzi) FROM stdin;
    public          postgres    false    220   ��       d          0    24773    navigazione 
   TABLE DATA           :   COPY public.navigazione (idcorsa, codnatante) FROM stdin;
    public          postgres    false    221   Q�       e          0    24776 
   passeggero 
   TABLE DATA           N   COPY public.passeggero (idpasseggero, nome, cognome, datanascita) FROM stdin;
    public          postgres    false    222   ��       f          0    24779    prenotazione 
   TABLE DATA           �   COPY public.prenotazione (idcorsa, idpasseggero, sovrapprezzoprenotazione, sovrapprezzobagagli, idprenotazione, peso_bagaglio, auto) FROM stdin;
    public          postgres    false    223   a�       q           0    0    prenotazione_idprenotazione_seq    SEQUENCE SET     O   SELECT pg_catalog.setval('public.prenotazione_idprenotazione_seq', 155, true);
          public          postgres    false    224            r           0    0    sequenza_id_passeggero    SEQUENCE SET     F   SELECT pg_catalog.setval('public.sequenza_id_passeggero', 122, true);
          public          postgres    false    225            �           2606    24788 $   bigliettointero bigliettointero_pkey 
   CONSTRAINT     m   ALTER TABLE ONLY public.bigliettointero
    ADD CONSTRAINT bigliettointero_pkey PRIMARY KEY (codbigliettoi);
 N   ALTER TABLE ONLY public.bigliettointero DROP CONSTRAINT bigliettointero_pkey;
       public            postgres    false    214            �           2606    24790 &   bigliettoridotto bigliettoridotto_pkey 
   CONSTRAINT     o   ALTER TABLE ONLY public.bigliettoridotto
    ADD CONSTRAINT bigliettoridotto_pkey PRIMARY KEY (codbigliettor);
 P   ALTER TABLE ONLY public.bigliettoridotto DROP CONSTRAINT bigliettoridotto_pkey;
       public            postgres    false    215            �           2606    24792 *   cadenzagiornaliera cadenzagiornaliera_pkey 
   CONSTRAINT     |   ALTER TABLE ONLY public.cadenzagiornaliera
    ADD CONSTRAINT cadenzagiornaliera_pkey PRIMARY KEY (nomecadenzagiornaliera);
 T   ALTER TABLE ONLY public.cadenzagiornaliera DROP CONSTRAINT cadenzagiornaliera_pkey;
       public            postgres    false    216            �           2606    24794 2   compagniadinavigazione compagniadinavigazione_pkey 
   CONSTRAINT     {   ALTER TABLE ONLY public.compagniadinavigazione
    ADD CONSTRAINT compagniadinavigazione_pkey PRIMARY KEY (nomecompagnia);
 \   ALTER TABLE ONLY public.compagniadinavigazione DROP CONSTRAINT compagniadinavigazione_pkey;
       public            postgres    false    217            �           2606    24796    corsa corsa_pkey 
   CONSTRAINT     S   ALTER TABLE ONLY public.corsa
    ADD CONSTRAINT corsa_pkey PRIMARY KEY (idcorsa);
 :   ALTER TABLE ONLY public.corsa DROP CONSTRAINT corsa_pkey;
       public            postgres    false    218            �           2606    24798 $   indirizzosocial indirizzosocial_pkey 
   CONSTRAINT     i   ALTER TABLE ONLY public.indirizzosocial
    ADD CONSTRAINT indirizzosocial_pkey PRIMARY KEY (indirizzo);
 N   ALTER TABLE ONLY public.indirizzosocial DROP CONSTRAINT indirizzosocial_pkey;
       public            postgres    false    219            �           2606    24800    compagniadinavigazione mail 
   CONSTRAINT     V   ALTER TABLE ONLY public.compagniadinavigazione
    ADD CONSTRAINT mail UNIQUE (mail);
 E   ALTER TABLE ONLY public.compagniadinavigazione DROP CONSTRAINT mail;
       public            postgres    false    217            �           2606    24802    natante natante_pkey 
   CONSTRAINT     Z   ALTER TABLE ONLY public.natante
    ADD CONSTRAINT natante_pkey PRIMARY KEY (codnatante);
 >   ALTER TABLE ONLY public.natante DROP CONSTRAINT natante_pkey;
       public            postgres    false    220            �           2606    24804    navigazione navigazione_pkey 
   CONSTRAINT     k   ALTER TABLE ONLY public.navigazione
    ADD CONSTRAINT navigazione_pkey PRIMARY KEY (idcorsa, codnatante);
 F   ALTER TABLE ONLY public.navigazione DROP CONSTRAINT navigazione_pkey;
       public            postgres    false    221    221            �           2606    24806    passeggero passeggero_pkey 
   CONSTRAINT     b   ALTER TABLE ONLY public.passeggero
    ADD CONSTRAINT passeggero_pkey PRIMARY KEY (idpasseggero);
 D   ALTER TABLE ONLY public.passeggero DROP CONSTRAINT passeggero_pkey;
       public            postgres    false    222            �           2606    24808    prenotazione prenotazione_pkey 
   CONSTRAINT     h   ALTER TABLE ONLY public.prenotazione
    ADD CONSTRAINT prenotazione_pkey PRIMARY KEY (idprenotazione);
 H   ALTER TABLE ONLY public.prenotazione DROP CONSTRAINT prenotazione_pkey;
       public            postgres    false    223            �           2606    24810    compagniadinavigazione sitoweb 
   CONSTRAINT     \   ALTER TABLE ONLY public.compagniadinavigazione
    ADD CONSTRAINT sitoweb UNIQUE (sitoweb);
 H   ALTER TABLE ONLY public.compagniadinavigazione DROP CONSTRAINT sitoweb;
       public            postgres    false    217            �           2606    24812    compagniadinavigazione telefono 
   CONSTRAINT     ^   ALTER TABLE ONLY public.compagniadinavigazione
    ADD CONSTRAINT telefono UNIQUE (telefono);
 I   ALTER TABLE ONLY public.compagniadinavigazione DROP CONSTRAINT telefono;
       public            postgres    false    217            �           2620    24813 &   prenotazione after_insert_prenotazione    TRIGGER     �   CREATE TRIGGER after_insert_prenotazione AFTER INSERT ON public.prenotazione FOR EACH ROW EXECUTE FUNCTION public.after_insert_prenotazione();
 ?   DROP TRIGGER after_insert_prenotazione ON public.prenotazione;
       public          postgres    false    248    223            �           2620    24814    corsa aggiungi_navigazione    TRIGGER     ~   CREATE TRIGGER aggiungi_navigazione AFTER INSERT ON public.corsa FOR EACH ROW EXECUTE FUNCTION public.aggiungi_navigazione();
 3   DROP TRIGGER aggiungi_navigazione ON public.corsa;
       public          postgres    false    218    242            �           2620    24815 %   prenotazione diminuisci_disponibilita    TRIGGER     �   CREATE TRIGGER diminuisci_disponibilita AFTER INSERT ON public.prenotazione FOR EACH ROW EXECUTE FUNCTION public.diminuisci_disponibilita();
 >   DROP TRIGGER diminuisci_disponibilita ON public.prenotazione;
       public          postgres    false    223    243            �           2620    24816 *   prenotazione diminuisci_disponibilita_auto    TRIGGER     �   CREATE TRIGGER diminuisci_disponibilita_auto AFTER INSERT ON public.prenotazione FOR EACH ROW EXECUTE FUNCTION public.diminuisci_disponibilita_auto();
 C   DROP TRIGGER diminuisci_disponibilita_auto ON public.prenotazione;
       public          postgres    false    223    244            �           2620    24817 !   prenotazione elimina_prenotazione    TRIGGER     �   CREATE TRIGGER elimina_prenotazione AFTER DELETE ON public.prenotazione FOR EACH ROW EXECUTE FUNCTION public.elimina_prenotazione();
 :   DROP TRIGGER elimina_prenotazione ON public.prenotazione;
       public          postgres    false    223    245            �           2620    24818    corsa imposta_disponibilita    TRIGGER     �   CREATE TRIGGER imposta_disponibilita AFTER INSERT ON public.corsa FOR EACH ROW EXECUTE FUNCTION public.imposta_disponibilita();
 4   DROP TRIGGER imposta_disponibilita ON public.corsa;
       public          postgres    false    218    226            �           2620    24819 #   passeggero incrementa_id_passeggero    TRIGGER     �   CREATE TRIGGER incrementa_id_passeggero BEFORE INSERT ON public.passeggero FOR EACH ROW EXECUTE FUNCTION public.incrementa_id_passeggero();
 <   DROP TRIGGER incrementa_id_passeggero ON public.passeggero;
       public          postgres    false    227    222            �           2620    24820 !   natante incrementa_numero_natanti    TRIGGER     �   CREATE TRIGGER incrementa_numero_natanti AFTER INSERT ON public.natante FOR EACH ROW EXECUTE FUNCTION public.incrementa_numero_natanti();
 :   DROP TRIGGER incrementa_numero_natanti ON public.natante;
       public          postgres    false    228    220            �           2620    24821    corsa modifica_ritardo    TRIGGER     �   CREATE TRIGGER modifica_ritardo AFTER UPDATE OF ritardo ON public.corsa FOR EACH ROW EXECUTE FUNCTION public.modifica_ritardo();
 /   DROP TRIGGER modifica_ritardo ON public.corsa;
       public          postgres    false    218    229    218            �           2620    24822    prenotazione prezzo_bagaglio    TRIGGER     |   CREATE TRIGGER prezzo_bagaglio BEFORE INSERT ON public.prenotazione FOR EACH ROW EXECUTE FUNCTION public.prezzo_bagaglio();
 5   DROP TRIGGER prezzo_bagaglio ON public.prenotazione;
       public          postgres    false    230    223            �           2620    24823 +   prenotazione setta_sovrapprezzoprenotazione    TRIGGER     �   CREATE TRIGGER setta_sovrapprezzoprenotazione BEFORE INSERT ON public.prenotazione FOR EACH ROW EXECUTE FUNCTION public.setta_sovrapprezzoprenotazione();
 D   DROP TRIGGER setta_sovrapprezzoprenotazione ON public.prenotazione;
       public          postgres    false    246    223            �           2620    24824 (   prenotazione verifica_disponibilita_auto    TRIGGER     �   CREATE TRIGGER verifica_disponibilita_auto BEFORE INSERT ON public.prenotazione FOR EACH ROW EXECUTE FUNCTION public.verifica_disponibilita_auto();
 A   DROP TRIGGER verifica_disponibilita_auto ON public.prenotazione;
       public          postgres    false    247    223            �           2606    24825    corsa corsa_nomecompagnia_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.corsa
    ADD CONSTRAINT corsa_nomecompagnia_fkey FOREIGN KEY (nomecompagnia) REFERENCES public.compagniadinavigazione(nomecompagnia);
 H   ALTER TABLE ONLY public.corsa DROP CONSTRAINT corsa_nomecompagnia_fkey;
       public          postgres    false    3238    217    218            �           2606    24830    bigliettointero idpasseggero    FK CONSTRAINT     �   ALTER TABLE ONLY public.bigliettointero
    ADD CONSTRAINT idpasseggero FOREIGN KEY (idpasseggero) REFERENCES public.passeggero(idpasseggero);
 F   ALTER TABLE ONLY public.bigliettointero DROP CONSTRAINT idpasseggero;
       public          postgres    false    222    214    3254            �           2606    24835    bigliettoridotto idpasseggero    FK CONSTRAINT     �   ALTER TABLE ONLY public.bigliettoridotto
    ADD CONSTRAINT idpasseggero FOREIGN KEY (idpasseggero) REFERENCES public.passeggero(idpasseggero);
 G   ALTER TABLE ONLY public.bigliettoridotto DROP CONSTRAINT idpasseggero;
       public          postgres    false    222    215    3254            �           2606    24840 2   indirizzosocial indirizzosocial_nomecompagnia_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.indirizzosocial
    ADD CONSTRAINT indirizzosocial_nomecompagnia_fkey FOREIGN KEY (nomecompagnia) REFERENCES public.compagniadinavigazione(nomecompagnia);
 \   ALTER TABLE ONLY public.indirizzosocial DROP CONSTRAINT indirizzosocial_nomecompagnia_fkey;
       public          postgres    false    219    3238    217            �           2606    24845 "   natante natante_nomecompagnia_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.natante
    ADD CONSTRAINT natante_nomecompagnia_fkey FOREIGN KEY (nomecompagnia) REFERENCES public.compagniadinavigazione(nomecompagnia);
 L   ALTER TABLE ONLY public.natante DROP CONSTRAINT natante_nomecompagnia_fkey;
       public          postgres    false    220    3238    217            �           2606    24850 '   navigazione navigazione_codnatante_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.navigazione
    ADD CONSTRAINT navigazione_codnatante_fkey FOREIGN KEY (codnatante) REFERENCES public.natante(codnatante);
 Q   ALTER TABLE ONLY public.navigazione DROP CONSTRAINT navigazione_codnatante_fkey;
       public          postgres    false    3250    220    221            �           2606    24855 $   navigazione navigazione_idcorsa_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.navigazione
    ADD CONSTRAINT navigazione_idcorsa_fkey FOREIGN KEY (idcorsa) REFERENCES public.corsa(idcorsa);
 N   ALTER TABLE ONLY public.navigazione DROP CONSTRAINT navigazione_idcorsa_fkey;
       public          postgres    false    218    221    3246            �           2606    24860    corsa nomecadenzagiornaliera    FK CONSTRAINT     �   ALTER TABLE ONLY public.corsa
    ADD CONSTRAINT nomecadenzagiornaliera FOREIGN KEY (nomecadenzagiornaliera) REFERENCES public.cadenzagiornaliera(nomecadenzagiornaliera);
 F   ALTER TABLE ONLY public.corsa DROP CONSTRAINT nomecadenzagiornaliera;
       public          postgres    false    218    3236    216            �           2606    24865 &   prenotazione prenotazione_idcorsa_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.prenotazione
    ADD CONSTRAINT prenotazione_idcorsa_fkey FOREIGN KEY (idcorsa) REFERENCES public.corsa(idcorsa);
 P   ALTER TABLE ONLY public.prenotazione DROP CONSTRAINT prenotazione_idcorsa_fkey;
       public          postgres    false    218    3246    223            �           2606    24870 +   prenotazione prenotazione_idpasseggero_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.prenotazione
    ADD CONSTRAINT prenotazione_idpasseggero_fkey FOREIGN KEY (idpasseggero) REFERENCES public.passeggero(idpasseggero);
 U   ALTER TABLE ONLY public.prenotazione DROP CONSTRAINT prenotazione_idpasseggero_fkey;
       public          postgres    false    223    3254    222            ]   *  x�}V�r�8<K_1_�� ������R�VN�(c��*YJifrدߖG�dbAg$��h D%IU��z(�}3>���X��T޻:�r�����,��}3�M���%�{�},�#�v_J�5Utu��;�?�eD�?c�2�Ǧo*���:�R�}��w~���9�0���폥ov���7�Y�̵�wA��8qWN]iv��<�M�sE��s��G�n���e��+�Ϧ���Ï�P�C�rM����7]{8����ڏS}�j����Q�ku���;���9�|���l�v���^J;"j��¥������ILq)�8�x�C���ۮ���ęҌ���9������~*�e�w�ơ�\{/YL�)P�pN�@�v�sW�����AE��[�&������_au5ǋ.�O�f.��Z5���	��Io�^1������_?N��rMNs�-�4s"ݐ;g�s�Sr��x:�o���E�)���ۮ9=����|
P|HzE��^}�bi��&cJJ��9�N�:�{U��������>���>�6;�7����P^A���H=�6h.p��JL"�~��nQyT6u�lr�f�-�}#+M�!�<�M��1���B);��pq���Df��܋�0s\���#�4����dy~���Eo��cH���Q���h2�F�Ѭ:1�_7���M�S�]�q"�I��E1�k\.^�����X3�	^�VοZ���=����˰��SBY}4�H1�hV''c8n99�bO䍑��n9��X�'�c�o��&�p����6~�����Z��.�q��O��P`Y�ڄeϗ�*4�A���62/�[M �7xSvqn�5��,�+�S��mr�\}��:6Ac&�I	�v+W0�̛ED�%�����hCL�T��`�� b��>�#��3� ��,	S��h����
+��̍�92�@ؙ`I�6�A�s��"�̢�W�f*�Y�iA��-GI�L]`/�(y�M6�UM!�?"�b+�7�NjC��wC�șQ �Č���,8b-�/�]�Mv9'&}!e�KA6�I\�)`,���_��u�?@�.4      ^     x�}��j1Ek�+��F��L�6bH�F�,�W��4��(��8R���}hL,��vO��:��X���$xQ��m�
����t.Kަ�8a/�w���**=��{��<Y�[��MU[�y)��'��N_s���R��R]Y=	�0����*|�S����91"����A1��c��1�#ZRi/aJ	��a	���� ��BJܫ��(�:	�$l�B�F�	MA;�k�+�����_51�`;/Ge��	����z����+]��      _   �  x����n�0���)� �m�Vɳ��@��h�FưR��clC����t�()�;3g~PB�p������^���>!�Ӯ�-ŅG>��)0��9�o�;�`�����K��>aW�b��%��v�`�8�HU�:@�����s�������6'�f
?��'�~�B�G�!;�ufN��)Ǡ�n ��� ���ee��6x�TN��JD�E�%_v��c����i&m�#��[vl��'�dR$�mk�ͻ�AS�����G����*�g�%�U=��ꨶ�gm�<v�ѣ�����e�Z��(�(,�.��.�6ML���~�����2�^�����_@�9�zr4��~i�|M��8��sxq��89��5K�Jf�#���<H��[	4�����m������MWp>>����H�ظ���ʋmK�khy�z���*GoS�(߸�Q���f<�<�jV���|�	-W�\�]t���?���z8�x����Q���A�g      `   �   x�]�K�0�ϛ��<n-�CM/=zYTڀ&E���"�ag��q���{L�4����"�댽G(�q!�Ric!��->5q�<�|�r�gr�9�{������R
bhq'�~�Vց��zyL�c�s!�����͇�?�zRSB���GZ      a   R  x���͎�0F��)�uE�t)�"��4�h6�L����U��0�V'�JQ� ������[��_1)	�ӯ	Fir��Y�^3T^ ��S�NH.����ٌw���~�B��<�����������	�KĚ�'�j��ĦMKZ:�<�H���dEx�O��p��o�x���4�Y�b�dNA���%�*"�O*N�	�u/EQz �O"NjQ2gԛI��j,�SK�4�Ӹ�'�/i����+Ԑ����a
��ߔ���jf���R���#>�Ѡ4v�Ė�`k��r� ڛ$m[���6��7>㗆�K��'���A �N��3Nޗ�TT:���peT��25���8CQO�Y����ҋV�o�r��	��V� m4�B�<r��G�� oe���x*}�m4u����+1V��D[�#��8�S��c������Z�RN���� �~Oߝ���NZ��Uz;�A�[�YDR�*���#�<�#E�ym�֖�I��CJ������ �J2@O�7�t���K��������ImG�G;ҵ�[�����*���(�6 ��C��� º�ڵ��oC�R�:���~�,�/�y�t      b   \   x�M�1
� ��w�N����jq?���D<�Cm����SAprNvAPj+z$]�o��!��>���-�^�����RD�������)-      c   �   x�}�1� ���1Ziu4����8�\-I� �?_Ф��0��;'�t�~Y����g�`mf��W���V���w�Fp�u�|�!a$O'���D��&�$P~7%�������5B��&�ى�?��V�{��.���1��]q      d   F   x����0г=LU�a��?G<K`!�B�R;PT@^g;��nl��F�������i97��O��=$�S$      e   �  x���Ko#)���+f7�q��LܝVK�(�z5�T'H�"*�Y����R��f�H����8��Y��M?�n9�+�U�J'�����~ܼ�5k+�*]KR����⮟&?�%�VJW�$��z��q�֏1��U�����ţ�Cq��{>�*�cI���pS���?�f��4QEFR#n���bG�hlE��ZR�R؇ыo~҅��v��=~2n��g�JQ��_�>�q��>n�~z���,ǁ��|o�"���x
�8�h?>�ښ��R+D��c��K�����a���(B���S��a��#��j���Z���ݏ����-���R�5I]�_~�G�y�Î�l�vm�n��q
h�c?�˔�M��j�[D�a�~��S�p���w~��W��/E�JwR�;�#�����9ⱨ�~�Gn@ȩ QI�Tc\�&�%p���P���u
�=�%~�a�9��8-k��0�v��>�J�N�Z<��k?�����m�;fd]g�yH���:�,OY@�u#�����;(w�Y֨+�R���{���
/�6�E��;d��B��!�����hdm�}�=�����B>�D��m�Ӂ�Q����0H�t�t8��9`[�J6
��T�,¹�ibp�l(u#�7��q�D5Z�xF;v��M�ceS�/a��ġ�ijeӔ4ŗ?o�IEYy*�Ѵ�<\ų_ä5���[�c�L!%@u�Vc��!	)||ryZ.���!`�n��9G���F�zc�?Iw�mx�٪�pb��8ϩu�鴨�g%��šצ
��0rK����N�A"��<�II��If���j�eۜ�4��Vؗ�ne{2��XM����v���K��ٚ���Oͩ�O���:�����|,�g�.��7f��8}��'�g�?�g������3��}v͵}��>���>�i"�n�>s6l�����R	t���YJ��ܵ}���O��3��i��>�V�O�/�3�b�4��}�B�4i=��>�Oޗ�a�α�~�,'�5�$�\�^|��~J�`��>���b�A�k��K�S?��LE�s©�޳י�Ղ��O�Ş����N��6&�wz	�fv,��X�;��Y��{��mܹA_��o��.����gAP�f�Za��x�V�ܹ�-
��YH�^� 3�n�Nx�|��m�3��%j�,pەi��k��\��M������� ��5���*�?��fy;:��lQ���������5ٹ�����
\w��3��� 3C����Y�`q�O���2� TW&ꄡ����Nv���)�T�#)��c���G����Rk��T��f�3=�:��K�@�T���)/�?��G��k� ��ܬq�_�Ο;�g� *�z��/N�$D�b�C�,A`���^����Wi	&�
�.���-���3�e� r���ϊ]�
�t�� ��P�?I)�^��2      f   Z  x�m�[�1E��Ŵl��Md���0`W�V��66\�TU�Z�W�ھ����"t��wl��{���*�k�T!������ҡN�������`I%��<� tiUU:���Ju%�h�AL�eAh~V��bY踐Rq~Ú�SՇ�Ӡ/W��a���q�Іk�:�VW�\�rA�^�ҏ�I��ʧY=;��jhc�Q�
�e��[$��N"��Fs���-5m�V����G0 Ve.��	}�mܝ��\��%3�iW��\dx���V�0��8�E�D2�X'⛩�Ҹ�<S��cZ?��,�P��L�2v���-��E.`oe=k��'C-hq\c(`����M��Q Դ�ȁޥ�f�㙻14w�,�����8/E�l-/8�ƞ��^�p��=O����# ��9��p��p��V	z��LaY����P�	�rh��rx�e�V��z	
�P(܅E�,�M!�H2��;�ꌳ��:��ү�u&ݯ�r�(���bi'zT��Q����Fu��=�N�l?{8N� �����;w�f$�f�=�{t���A�c8v[]n_*���t��X7_�g9��n��It_o">|O�D/�'��]�u���6���}g<h�p�ٚ@`N�VE7i�8��*��k�YV5���p�N�p���b܂����K����k���ƺ�y�_�׺�_��R�u޴�Te|k�^m
��\%Tr6,8Tv8L=�-�����|�6��E]���-�X�Zu=~��ɟ��h�h�h�h-�z��D�����0�L|`�����&>0�J|P�����%>(�A�J|P�����'>8���N|p���h���>~�����J�     