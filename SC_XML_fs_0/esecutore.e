note
	description: "Summary description for {ESECUTORE}."
	author: ""
	date: "$Date$"
	revision: "$Revision$"

class
	ESECUTORE

create
	start, start_new

feature --Attributi
	--	conf: CONFIGURAZIONE

	stato_iniziale: STATO

	stati: HASH_TABLE [STATO, STRING]

	configuratore: CONFIGURAZIONE

	condizioni: HASH_TABLE [BOOLEAN, STRING]
			-- serve durante l'istanziazione iniziale di stati, transizione e configurazione
			-- una volta che � terminata non serve pi�
			--	condizioni: HASH_TABLE [STRING, STRING]
			--eventi: ARRAY[STRING]
			-- serve durante la lettura degli eventi dal file

	count_evento_corrente: INTEGER --tiene il conto del numero di eventi gi� processati,
			--serve per la leggi_prossimo_evento

	eventi: ARRAY [STRING]

feature {NONE} -- Inizializzazione

	start
			-- Run application.
		local
			s_orig: SIMPLE_MODIFIED
			albero: XML_CALLBACKS_NULL_FILTER_DOCUMENT
		do
			create stato_iniziale.make_empty
			stato_iniziale.set_final
			create stati.make (1)
			create condizioni.make (1)
			count_evento_corrente := 1
			print ("INIZIO!%N")
			create s_orig.make
			print ("FINE!%N")
			albero := s_orig.tree
			crea_stati_e_cond (albero)
			create configuratore.make_with_condition (stato_iniziale, condizioni)
			eventi := acquisisci_eventi
			print ("cristiano � brutto")
		end

	start_new (un_file: STRING)
		local
			parser: XML_PARSER
			albero: XML_CALLBACKS_TREE
		do
				--| Instantiate parser
			create {XML_STANDARD_PARSER} parser.make
				--| Build tree callbacks
			create albero.make_null
			parser.set_callbacks (albero)
				--| Parse the `file_name' content
			parser.parse_from_filename (un_file)
			if parser.error_occurred then
				print ("Parsing error!!! %N")
			else
				print ("Parsing OK. %N")
			end
			create stato_iniziale.make_empty
			create eventi.make_empty
			create stati.make (1)
			create condizioni.make (1)
			create configuratore.make_with_condition (stato_iniziale, condizioni)
			print ("INIZIO!%N")
			crea_stati_e_cond (albero)
			eventi := acquisisci_eventi
			print ("acquisiti eventi")
			create configuratore.make_with_condition (stato_iniziale, condizioni)
		end

feature -- Cose che si possono fare

	evolvi_SC
		local
			evento_corrente: STRING
			st: detachable STATO
		do
			FROM
			UNTIL
				configuratore.stato_corrente.finale or count_evento_corrente > eventi.count
			LOOP
				configuratore.chiusura
				evento_corrente := current.leggi_prossimo_evento
				IF NOT configuratore.stato_corrente.determinismo (evento_corrente, configuratore.condizioni) THEN
					print ("ERRORE!!! Non c'� determinismo!!!")
				ELSE
					st := configuratore.stato_corrente.target (evento_corrente, configuratore.condizioni)
					if attached st as s then
						configuratore.set_stato_corrente (s)
					end
				end
			end
			if not configuratore.stato_corrente.finale then
				configuratore.chiusura
			end
		end

	crea_stati_e_cond (albero: XML_CALLBACKS_NULL_FILTER_DOCUMENT)
			--				questa feature dovra creare l'hashtable con gli stati istanziati e le transizioni,
			--				anche garantendo che le transizioni hanno target leciti
		local
			temp_stato: STATO
			flag: BOOLEAN
			first: XML_NODE
			tempatt: detachable XML_ATTRIBUTE
			lis_el: LIST [XML_ELEMENT]
			lis_data: LIST [XML_ELEMENT]
		do
			first := albero.document.first
			flag := false
			if attached {XML_ELEMENT} first as f then
				lis_el := f.elements
				from
					lis_el.start
				until
					lis_el.after
				loop
					if lis_el.item_for_iteration.name ~ "final" then
						tempatt := lis_el.item_for_iteration.attribute_by_name ("id")
						if attached tempatt as asd then
							create temp_stato.make_with_id (asd.value)
							stati.extend (temp_stato, asd.value)
							temp_stato.set_final
						end
					end
					if lis_el.item_for_iteration.name ~ "state" then
						tempatt := lis_el.item_for_iteration.attribute_by_name ("id")
						if attached tempatt as asd then
							create temp_stato.make_with_id (asd.value)
							stati.extend (temp_stato, asd.value)
						end
					elseif lis_el.item_for_iteration.name ~ "datamodel" then
						lis_data := lis_el.item_for_iteration.elements
						from
							lis_data.start
						until
							lis_data.after
						loop
							if attached {XML_ATTRIBUTE} lis_data.item_for_iteration.attribute_by_name ("id") as nome then
								if attached {XML_ATTRIBUTE} lis_data.item_for_iteration.attribute_by_name ("expr") as valore then
									condizioni.extend ( valore.value ~ "true", nome.value)
								end
							end
							lis_data.forth
						end
					end
					lis_el.forth
				end
				--assegno chi � l'iniziale
				if attached f.attribute_by_name ("initial") as primo_stato then
					stato_iniziale:=stati.item (primo_stato.value)
				end

				--stati istanziati, ora li riempiamo
				from
					lis_el.start
				until
					lis_el.after
				loop
					if lis_el.item_for_iteration.name ~ "state" then
						tempatt := lis_el.item_for_iteration.attribute_by_name ("id")
						if attached tempatt as asd then
							riempi_stato (asd.value, lis_el.item_for_iteration)
						end
					end
					lis_el.forth
				end
			end
		end

	riempi_stato (chiave: STRING; element: XML_ELEMENT)
		local
			temp_stato: DETACHABLE STATO
			lis_el: LIST [XML_ELEMENT]
			lis_el2: LIST [XML_ELEMENT]
			transizione: TRANSIZIONE
			azione: detachable XML_ATTRIBUTE
			event: detachable XML_ATTRIBUTE
			con: detachable XML_ATTRIBUTE
			target: detachable XML_ATTRIBUTE
			assegn: ASSEGNAZIONE
			finta: FITTIZIA
			location: STRING
			val: BOOLEAN
		do
			lis_el := element.elements
			from
				lis_el.start
			until
				lis_el.after
			loop
				if lis_el.item_for_iteration.name ~ "transition" then
					target := lis_el.item_for_iteration.attribute_by_name ("target")
					if attached target then
						if attached stati.item (target.value) as fabio then
							create transizione.make_with_target (fabio)
							event := lis_el.item_for_iteration.attribute_by_name ("event")
							if attached event then
								transizione.set_evento (event.value)
							end
							con := lis_el.item_for_iteration.attribute_by_name ("cond") -- non sappiamo come l'xml chiama le condizioni
							if attached con then
								transizione.set_condizione (con.value)
							end
							lis_el2 := lis_el.item_for_iteration.elements
							from
								lis_el2.start
							until
								lis_el2.after
							loop
								if lis_el2.item_for_iteration.name ~ "assign" then
									if attached lis_el2.item_for_iteration.attribute_by_name ("location") as luogo then
										if attached lis_el2.item_for_iteration.attribute_by_name ("expr") as expr then
											if expr.value ~ "false"  then
												create assegn.make_with_cond_and_value (luogo.value, FALSE)
												transizione.set_azione (assegn)
											end
										end
									end
								end
								if lis_el2.item_for_iteration.name ~ "log" then
										if attached lis_el2.item_for_iteration.attribute_by_name ("name") as name then
											create finta.make_with_id (name.value)
											transizione.set_azione (finta)
										end
									end
								lis_el2.forth
							end
							temp_stato := stati.item (chiave)
							if attached temp_stato then
								temp_stato.agg_trans (transizione)
							end
						else
							temp_stato := stati.item (chiave)
							if attached temp_stato then
								print ("lo stato" + temp_stato.id + "ha una transizione non valida %N")
							end
						end
					end
				end
				lis_el.forth
			end
		end

		-- Aggiungere 'feature' per tracciare quanto accade scrivendo su file model_out.txt:
		--la SC costruita dal programma (cio� il file model.xml letto)
		--la configurazione iniziale in termini di stato e nomi-valori delle condizioni
		--l'evoluzione della SC in termini di sequenza di quintuple:
		--stato, evento, condizione, azione, target

feature --eventi

	leggi_prossimo_evento: STRING
			-- Questa serve a leggere l'evento corrente

		do
			Result := eventi [count_evento_corrente]
			count_evento_corrente := count_evento_corrente + 1
		end

	acquisisci_eventi: ARRAY [STRING]
			-- Legge gli eventi dal file 'eventi.txt' e li inserisce in un vettore

		local
			file: PLAIN_TEXT_FILE
			v_eventi: ARRAY [STRING]
			i: INTEGER
		do
			create v_eventi.make_empty
			create file.make_open_read ("eventi.txt")
			from
				i := 1
			until
				file.off
			loop
				file.read_line
				v_eventi.force (file.last_string.twin, i)
				i := i + 1
			end
			file.close
			Result := v_eventi
		end

		--			ottieni_evento: STRING --serve a verificare che tutti gli eventi nel file eventi.txt compaiano effettivamente
		--								   --tra gli eventi di qualche transizione
		--					  local
		--					    evento_letto: STRING
		--				do
		--					Result := ""
		--						  FROM
		--						    evento_letto := leggi_prossimo_evento
		--						  UNTIL
		--						    count_evento_corrente>eventi.count
		--						  LOOP
		--						    messaggio_di_errore(evento_letto non � un evento legale)
		--						    evento_letto := leggi_prossimo_evento
		--						  END
		--						  IF evento_letto IN eventi THEN
		--						    Result := evento_letto
		--				end

	verifica_eventi: ARRAY [STRING]
			--Serve a verificare che tutti gli eventi nel file eventi.txt compaiano effettivamente tra gli eventi di qualche transizione
			--Comunica a video se ci sono eventi incompatibili
		local
			v_new, v_old: ARRAY [STRING]
			h_stati: HASH_TABLE [STATO, STRING]
			i, j, k: INTEGER
			flag, flag_1: BOOLEAN
		do
			create v_new.make_empty
			h_stati := current.stati
			v_old := current.eventi
			k := 1
			from
				i := 1
			until
				i = eventi.count + 1
			loop
				flag := False
				from
					h_stati.start
				until
					h_stati.after OR flag
				loop
					flag_1 := False
					if attached h_stati.item_for_iteration.get_events as tp then
						from
							j := 1
						until
							j = tp.count + 1 or flag_1
						loop
							if tp [j] ~ v_old [i] then
								v_new.force (v_old [i].twin, k)
								k := k + 1
								flag_1 := True
								flag := True
							else
								j := j + 1
							end
						end
					end
					h_stati.forth
				end
				if NOT flag then
					print ("%N SANTIDDIO!! L'evento " + v_old [i] + " non viene utilizzato!")
				end
				i := i + 1
			end
			Result := v_new
		end

end
