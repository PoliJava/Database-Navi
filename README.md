# README
Questa repository contiene il codice SQL del Database fatto per il progetto di Basi di Dati I ed Object Orientation, coprendo il lato relativo alla base di dati con la relativa documentazione.

# COMMENTI:
Sulle tuple, dei commenti contrassegnano i trigger associati a ciascunadi esse.
Sulla tupla "corsa":

-- Trigger: aggiungi_navigazione
-- Trigger: imposta_disponibilita
-- Trigger: modifica_ritardo

Sulla tupla "natante":

-- Trigger: incrementa_numero_natanti

Sulla tupla "passeggero":

-- Trigger: incrementa_id_passeggero

Sulla tupla "prenotazione":

-- Trigger: after_insert_prenotazione
-- Trigger: diminuisci_disponibilita
-- Trigger: diminuisci_disponibilita_auto
-- Trigger: elimina_prenotazione
-- Trigger: prezzo_bagaglio
-- Trigger: setta_sovrapprezzoprenotazione
-- Trigger: verifica_disponibilita_auto

I commenti sulle funzioni appartenenti ai trigger sono più di sostanza e spiegano cosa effettuano le funzioni man mano.

Sulla funzione "after_insert_prenotazione":

	-- se la disponibilita della corsa è uguale a zero, non è possibile effettuare la prenotazione e viene lanciata un'eccezione
	-- nella variabile data_corsa viene memorizzata la data di inizio della cadenza giornaliera corrispondente
	-- alla corsa specifica della prenotazione. Viene utilizzata per calcolare il sovrapprezzo della prenotazione
  -- la funzione concat concatena una stringa ad un'altra separata da uno spazio
  -- viene utilizzata la funzione random per generare un codice biglietto in maniera casuale. 
	-- la funzione floor viene utilizzata per indicare che i numeri devono essere interi
  -- queste istruzioni servono a calcolare la differenza tra una data ed un'altra.
	-- viene utilizzata la funzione extract per estrarre l'anno, il mese o il giorno da una data
	-- e successivamente la funzione age calcola la differenza (e quindi l'eta) tra i due valori.
 	-- se l'eta è minore di 18 anni, verrà effettuato un inserimento in bigliettoridotto
 	-- se la prenotazione viene effettuata prima della data di inizio del periodo in cui si attiva una corsa,
	-- allora viene aggiunto un sovrapprezzo alla prenotazione
  -- se la prenotazine invece viene effettuata durante il periodo in cui la corsa è attiva,
	-- allora non ci sarà nessun sovrapprezzo da aggiungere al prezzo totale
  -- l'eta è maggiore di 18 quindi l'inserimento viene effettuato in bigliettointero e acquistointero
  -- lo stesso ragionamento viene utilizzato per il calcolo in bigliettointero
  -- funzione che, dopo l''inserimento di una tupla in prenotazione, attiva il trigger che permette di aggiungere una tupla corrispondente in bigliettoridotto se l'età è minore di 18, oppure in 
  bigliettointero se l'età è maggiore di 18. Questa funzione inoltre permette di indicare l''eventuale sovrapprezzo della prenotazione o il sovrapprezzo dei bagagli, e di diminuire la disponibilità nella 
  tabella corsa';

Sulla funzione "aggiungi_navigazione":

-- Seleziona un natante per la stessa compagnia di navigazione della corsa appena inserita"
-- Seleziona casualmente un natante della stessa compagnia

Sulla funzione: "elimina_prenotazione":

	-- calcola l'età del passeggero
	-- se l'eta è minore di 18, allora le tuple vengono eliminate in acquistoridotto e bigliettoridotto
 	-- l'età è maggiore di 18 quindi le tuple vengono eliminate da acquistointero e bigliettointero
  -- aggiornamento della disponibilita dopo la cancellazione di una prenotazione

  Sulla funzione "imposta_disponibilita":

  -- Seleziona la capienza passeggeri e il tipo del natante associato alla corsa
  -- Seleziona la capienza passeggeri del natante associato alla corsa
  -- Verifica il tipo del natante e imposta la disponibilità della corsa di conseguenza
  -- Se il natante è un traghetto, la disponibilità è data dalla somma della capienza passeggeri e automezzi
  -- Altrimenti, la disponibilità è data solo dalla capienza passeggeri

  Sulla funzione "modifica_ritardo":
  
  -- condizione aggiunta per evitare che il ciclo prosegua all'infinito, 
	-- verificando se il nuovo ritardo è diverso dal vecchio ritardo
 	-- Se il nuovo ritardo non è nullo o 'canc' (indica che la corsa è stata cancellata), aggiorna la tabella corsa con il nuovo ritardo
  -- Altrimenti, imposta il ritardo a 'canc' nella tabella corsa

  Sulla funzione "setta_sovrapprezzoprenotazione":
  	-- se la prenotazione viene effettuata durante il periodo in cui si attiva la corsa, allora il sovrapprezzo è settato a 3
   	--altrimenti a 0

  Sulla funzione "verifica_disponibilita_auto":

  -- la funzione controlla anzitutto se ci sono ancora posti auto disponibili
  -- nel caso una prenotazione sia fatta su un tipo di nave che non ha posti auto, c'è un'exception:
