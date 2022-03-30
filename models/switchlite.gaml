/***
* Name: trafficgame
* Author: Carole Adam
* Description: simple interactive game about mobility and impact on pollution
* Actions directly update the values of 4 modes of transport (public transport, car, walk, cycle)
*   wrt 6 criteria (ecology, price, comfort, safe, easy, fast). Eg plant trees to make it more comfortable to walk
* Each individual has their own priority for the various criteria; picks best mode to do random trips
* Indicators: total kilometers travelled with each mode, number of trips for each mode, etc
* Tags : serious game, traffic, mobility, switch
* 
* source model
* Name: Traffic, * Author: Patrick Taillandier
* Description: A simple traffic model with a pollution model: the speed on a road depends on the number of people 
* on the road (the highest, the slowest), and the people diffuse pollution on the envrionment when moving.
* Tags: gis, shapefile, graph, skill, transport
*/

model switchlite

// simplified interface in a 2nd experiment
// TODO habits per context, weather, peak hour, etc? pas le thème de ce jeu, si ce n'est pour créer un peu d'inertie

// TODO calibrer les paramètres de la population (fitness, who has a bike, a car, a close bus stop)
//      d'après les stats INSEE, pour les supprimer des paramètres
// et supprimer les paramètres de l'interface

// TODO sliders pour les priorités moyennes des agents (pour favoriser la voiture)
// ou calibrer les priorités d'après une survey?


// TODO
// - satisfaction dépend des impôts
// - priorité du critère prix dépend des impôts
// - afficher un pie chart des modes préférés des citoyens (qui utilisent p-e un mode non préféré)
// - plutôt qu'un pie chart, afficher le nombre de trajets et de km fait pour chaque mode
// - afficher un pie chart du mode habituel des citoyens (le plus de trajets sur les 200 de l'année)
// - pression sociale : regarder les modes de transport des agents autour de soi
// - actions des agents : envisager consciemment de changer de mobilité, acheter voiture/vélo
// - changer pour voiture élec / moins polluante
// - budget individuel des agents, savoir s'ils peuvent payer bus / voiture, avec salaire annuel, et prio "eco" basée dessus
// - actions de communication: valoriser l'écologie, le vélo, la marche, la voiture électrique...
// - events aléatoiores au début de chaque année : canicule, grève, etc
// - historique de toutes les actions effectuées et de tous les événements
// - indicateur de sédentarité de la population
// - actions télétravail / horaires décalés, pour réduire la congestion à l'heure de pointe
// - communication sur sport, sédentarité, santé

// TODO doc : documenter l'ajout d'un bouton d'action

global {
	//Shapefile of the buildings
	//file building_shapefile <- file("../includes/buildings2.shp");
	//Shapefile of the roads
	//file road_shapefile <- file("../includes/roads.shp");
	//Shape of the environment
	//geometry shape <- envelope(road_shapefile);
	//Step value
	float step <- 10 #s;
	//Graph of the road network
	//graph road_network;
	//Map containing all the weights for the road network graph
	//map<road,float> road_weights;
	
	// TRANSPORT MODES
	// indexes for maps
	int BICYCLE <- 1;
	int CAR <- 2;
	int BUS <- 3;
	int WALK <- 4;
	list<int> transport_modes <- [BICYCLE, CAR, BUS, WALK];
	// STATIC - pollution per mode
	map<int,int> pollution_modes;
	
	// EVALUATION CRITERIA
	// indexes of criteria
	int ECOLO <- 1;
	int PRICE <- 2;
	int COMFORT <- 3;
	int SAFE <- 4;
	int EASY <- 5;
	int TIME <- 6;
	list<int> criteria <- [ECOLO, PRICE, COMFORT, SAFE, EASY, TIME];
	// TODO: additional HEALTH criteria? but very static (soft mobility always better)
	
	// PARAMETERS of the simulator (sliders in interface)
	//float move_proba;			// proba that agents move
	float roads_degrade_speed <- 0.1;  // factor of road degradation over time
	float accident_proba <- 0.1;		// probability of accident (will be weighed by congestion)
	// weather (TODO rain yes/no, cold yes/no), or float value from -1 (desagreeable) to +1 (very agreeable)
	float weather <- 0.5 min: 0.0 max: 1.0;
	
	// PARAMETERS OF POPULATION
	// priorities for criteria, must have one per criteria (not generic) to allow parameters in interface
	// TODO not used yet
	float avg_prio_ecolo;
	float avg_prio_price;
	float avg_prio_confort;
	float avg_prio_safe;
	float avg_prio_easy;
	float avg_prio_time;
	
	// other parameters
	float habit_drop_proba <- 0.05; 	//proba to reset habits
	float avg_fitness <- 0.5 min: 0.0 max: 1.0; // affects how easy/comfortable it is to walk/cycle
	// parameters affecting which transports modes are available to who
	float percent_has_bike <- 0.7 min: 0.0 max: 1.0;  // to be updated by policies to help buy a bike/ train to cycle
	float percent_has_car <- 0.9 min: 0.0 max: 1.0;   // to be updated by policies to forbid some cars
	float percent_can_walk <- 0.5 min: 0.0 max: 1.0;  // velo cargo
	
	// PARAMETERS OF BUS / PUBLIC TRANSPORT
	// FIXME ce paramètre est différent, ce n'est pas un attribut de la population mais de la couverture du réseau de bus
	float percent_close_bus <- 0.5 min: 0.0 max: 1.0; // to be updated by policies to build bus stops
	
	// PARAMETERS affected by player actions (urban management)
	float bus_price <- 0.5 min: 0.01;
	// frequency of buses : 1 means max freq, no wait between buses
	float bus_frequency <- 0.3 min: 0.1 max: 1.0; 
	int bus_capacity <- 30; //nb people per bus
	
	// MONEY MONEY
	float petrol_price <- 1.6 min: 0.01; // prix au litre - avoid div by zero
	float budget <- 0.0; // collecté sur les impôts en début de tour // <- 200.0;
	float tax_rate <- 5.0; // TODO: only on petrol? add a tax on petrol?
	int parking_price <- 0; 
	
	// map de coût de chaque action 
	map<int,int> actions_costs;
	
	// INDICATORS - to be displayed in game interface
	// bouchons / taux d'utilisation des routes
	float indic_circulation <- 1.0 min: 0.01 max: 1.0; // update: (road mean_of each.speed_coeff);
	// en fonction de l'infrastructure et du % d'utilisateurs de la voiture
	int speed_limit <- 50;
	
	// pollution (augmentée par les voitures)
	float indic_pollution <- 0.0;   // update: 0.01 * (cell mean_of each.pollution) ;
	// nombre d'arbres plantés (sur chaque cellule)
	int indic_trees <- 0;
	// damage on roads
	float avg_damage <- 0.0;
	int nb_roads_damaged <- 0;
	// accident rate (per number of trips)
	float accident_rate <- 0.0 min:0.0 max:1.0;
	
	// town safety (criminality) for pedestrians / public transports
	float town_safety <- 0.5 min: 0.0 max: 1.0; // FIXME init ?
	// bus congestion
	float indic_bus_congestion <- 0.0 min: 0.0 max: 1.0;
	int nb_bus_stops; // init based on density param, then increased +1 by action to build bus stop
	// happiness of population
	float indic_happiness <- 0.0;
	float indic_happy <- 0.0;
	float indic_accessibility <- 0.0; // how many can move at all
	
	// INFRASTRUCTURES
	float indic_carpark <- 0.9;
	float road_infrastructure <- 0.9;
	// % de routes équipées de pistes cyclables
	float cycling_infrastructure <- 0.1;
	// pedestrian infrastructure / sidewalk size
	float pedestrian_infrastructure <- 0.2;
	// bus dedicated lanes
	float bus_infrastructure <- 0.0;
	
	
	// TODO add vitesse limite autorisée
	// add capacité des routes (selon que voies dédiées aux bus / vélos / voitures)
	
	// count of distance / trips per year / overall 
	//map<int,int> total_km_travelled; // plus de distance
	//map<int,int> year_km_travelled;
	map<int,int> year_trips;
	map<int,int> total_trips;
	
	// histograms of distribution - 2 pairs, keys = "values" : value = list of values, key = "legends" : value=list of bins
	map<string, list> happydistrib;
	map<string,list> politicaldistrib;
	map<int,string> candidates;
	map<string,int> votes;
	
	// CRITERIA EVALUATION per mode (GLOBAL FOR NOW)
	map<int,map<int,float>> values_modes;  // indice 1 = criteria, indice 2 = mode
	// criteria eval for the whole town
	map<int,float> city_criteria;
	map<int,float> city_modes;
	
	// INTERFACE - IMAGES ON BUTTONS
	string dossierImages <-  "../includes/imgs/" ;
	int nbcol <- 4;
	list<image_file> images <- [];	// from sprite, 4 colonnes de 7 boutons	
	// which action was clicked in interface
	int action_type;
	
	// ************************
	// ***  INITIALISATION  ***
	// ************************
		
	init {
		// buttons with action number
		do init_buttons;
		do init_actions;
		
		// init values of criteria for each mode (for now random)
		do init_values_modes;
		write values_modes;
		
		// static map of pollution per mode - TODO: dynamic eby creating electric cars / buses
		put 10 at: CAR in: pollution_modes;
		put 1 at: BUS in: pollution_modes;
		put 0 at: WALK in: pollution_modes;
		put 0 at: BICYCLE in: pollution_modes;
		
		//Initialization of the building using the shapefile of buildings
		//create building from: building_shapefile;

		//Initialization of the road using the shapefile of roads
		//create road from: road_shapefile;
      	//Weights of the road
      	//road_weights <- road as_map (each::each.shape.perimeter);
      	//road_network <- as_edge_graph(road);
		
		//Creation of the people agents
		create people number: 100 {
			//People agents are located anywhere in one of the building
			//location <- any_location_in(one_of(building));
      	}
      	
      	loop i over: transport_modes {
			//year_km_travelled[i] <- 0;
			//total_km_travelled[i] <- 0;
			year_trips[i] <- 0;
			total_trips[i] <- 0;
			city_modes[i] <- 1.0;
		}
		
		// candidats et votes initiaux
		put "Mayor Toto" at: 0 in: candidates;
		put "Bambi" at: ECOLO in: candidates;
		put "Simba" at: EASY in: candidates;
		put "Koala" at: COMFORT in: candidates;
		put "Dollar" at: PRICE in: candidates;
		put "Prudent" at: TIME in: candidates;

		loop c over: candidates.values {
			put 0 at: c in: votes;
		}
      	
      	loop c over: criteria {
      		city_criteria[c] <- 1.0;
      	}
      	
      	// density of bus stops per cell / per agent
      	nb_bus_stops <- int(length(people) * percent_close_bus / 10);
	}//end init


	// not completely random - all static values computed once and for all here
	action init_values_modes {
		//créer la map dans la map avant d'y affecter des valeurs
		loop i over: criteria {
			map<int,float> m;
			values_modes[i] <- m;
		}
		
		// cars
		values_modes[ECOLO][CAR] <- 0.0;  	// depends on pollution ?
		values_modes[EASY][CAR] <- 1.0; 	// depends on parking
		values_modes[TIME][CAR] <- 0.6;	 	// depends on congestion, average duration of trips?
		values_modes[PRICE][CAR] <- 0.3; 	// petrol price and tax rate
		values_modes[COMFORT][CAR] <- 1.0; 	// always top comfort 
		values_modes[SAFE][CAR] <- 0.5; 	// depends on accident rate
		
		// bicycle
		values_modes[ECOLO][BICYCLE] <- 1.0;	// always max
		values_modes[EASY][BICYCLE] <- 1.0;		// always easy? 
		values_modes[TIME][BICYCLE] <- 0.8;		// always good
		values_modes[PRICE][BICYCLE] <- 1.0;    // always gratis
		values_modes[COMFORT][BICYCLE] <- 0.7;  // depends on hills, length of trip, age of people, pollution
		values_modes[SAFE][BICYCLE] <- 0.5;		// depends on cycling lanes ; accidents against bikes
		
		// walk
		values_modes[ECOLO][WALK] <- 1.0;		// always ecolo
		values_modes[EASY][WALK] <- 1.0; 		// always easy
		values_modes[TIME][WALK] <- 0.1;		// very slow
		values_modes[PRICE][WALK] <- 1.0;		// gratis
		values_modes[COMFORT][WALK] <- 0.5; 	// depends on trees and weather
		values_modes[SAFE][WALK] <- 0.3;		// depends on accidents against pedestrians? + town safety (cameras etc)
		
		// bus
		values_modes[ECOLO][BUS] <- 0.7;		// depends on bus capacity (the higher the best) 
		values_modes[EASY][BUS] <- 0.2; 		// depends on number of transfers, frequency, number of stops...
		values_modes[TIME][BUS] <- 0.4;			// depends on frequency, distance to stop...
		values_modes[PRICE][BUS] <- 0.5;		// depends on ticket/rego price
		values_modes[COMFORT][BUS] <- 0.5; 		// depends on capacity and number of actual passengers
		values_modes[SAFE][BUS] <- 0.4;			// depends on town safety	
	}
	

	
	// *****************************
	// *** INDICATORS and UPDATE ***
	// *****************************
	
	int nb_trips_year {
		int s <- sum(year_trips.values);
		return s=0?1:s;
	}
	
	
	action generate_accidents {
		// car against car, based on limit speed
		
		// car against bicycle, based on cycling infrastructure
	}
	
	action generate_congestion {
		// générer des bouchons selon horaires étalés ou pas, selon partage des infrastructures, selon accidents
	}


	// update indicators every (start of) year
	// TODO: à faire directement dans chaque action, sauf ceux qui updatent with time
	action update_indicators {
		
		// ONGOING: revoir tous les indicateurs en fonction des actions dispos !
		// ou bien: les actions modifient directement les indicateurs et il n'y a plus de reflex update
		
		//indic_circulation <- (road mean_of each.speed_coeff) with_precision 2;
		// FIXME ici year_trips est revenu à 0
		//indic_circulation <- road_infrastructure / (year_trips[CAR]+(year_trips[BUS]/bus_capacity)) with_precision 2;
		
		
		//indic_pollution <- 0.01 * (cell mean_of each.pollution) with_precision 2;
		// pollution augmentée par les km de chaque mode
		loop mode over: transport_modes {
			indic_pollution <- indic_pollution + 0.01 * pollution_modes[mode] * year_trips[mode];
			// TODO pollution_modes peut diminuer en rendant les voitures/bus électriques		
		}
		// pollution diminuée par les arbres
		indic_pollution <- indic_pollution - 0.01 * indic_trees;
		
		// done in actions now
		//indic_cyclability <- (road count each.cycle_lane) / length(road) with_precision 2;
		//indic_trees <- (cell sum_of each.trees_on_cell);
		
		// damage with time
		avg_damage <- avg_damage *(1-roads_degrade_speed);
		
		// accidents rate this year (count of accidents divided by number of km) (#trips too low)
		//accident_rate <- (road sum_of each.accident_count) / nb_km_year();
		// TODO accident_proba update selon les aménagements, leur saturation, la cohabitation des modes
		accident_rate <- accident_proba*year_trips[CAR] / nb_trips_year();
		
		// town safety can randomly decrease if not maintained
		town_safety <- (town_safety - rnd(0.1)) with_precision 2;
		
		// bus congestion in places per people (nb trips in a representative day, wrt number buses * places)
		//write("nb people in buses "+length(people where (each.mobility_mode = BUS)));
		//write("bus capacity per day "+bus_capacity * bus_frequency*100);  // TODO peak hours vs daily average...
		indic_bus_congestion <- length(people where (each.mobility_mode = BUS)) / (bus_capacity * bus_frequency);
		//write("my indic of congestion = "+indic_bus_congestion);
		
		// density of bus stops (per cell)
		// paramètre au départ, puis l'ajout de bus stop met l'attribut à vrai pour 10 personnes
		percent_close_bus <- (people count each.has_close_bus) / length(people);     //nb_bus_stops / length(cell);
		
		// happiness
		indic_happiness <- (people mean_of each.happiness) with_precision 2;
		indic_happy <- (people count each.happy) / length(people);
		//indic_accessibility <- (people count (each.mobility_mode > 0)) / length(people) with_precision 4;
		indic_accessibility <- (people count (each.mobility_mode > 0)) / length(people) with_precision 4;  // ; //is_stuck = false)) 
		// FIXME 1 JULY over the first 5 or so turns, this only increases, more and more people "can move"
		// or rather, more and more people "have moved"
		
		
		// at the end, to first use last year trips to update indicators
		// add km travelled last year and reset (even on last year)
		loop i over: transport_modes {		
			//total_km_travelled[i] <- total_km_travelled[i] + year_km_travelled[i];
			//year_km_travelled[i] <- 0;
			total_trips[i] <- total_trips[i] + year_trips[i];
			year_trips[i] <- 0;
		}
	}
	
	
	// reflex update_values_modes TODO remove modification in actions (indirect)
	// plutôt que le hardcoder dans les actions, il faut les recalculer
	// problème: on a 6 critères * 4 modes à calculer...
	action update_values_modes {
		// cars
		//values_modes[ECOLO][CAR] <- 0.0;  	// depends on pollution ? 1.0 - pollution_modes[CAR]/10;
		values_modes[EASY][CAR] <- indic_carpark; 	// depends on parking
		values_modes[TIME][CAR] <- 1-indic_circulation ;	 	// depends on congestion, average duration of trips?
		values_modes[PRICE][CAR] <- max([0,1-petrol_price/2]); 	// petrol price and tax rate
		//values_modes[COMFORT][CAR] <- 1-avg_damage; 	// depends on roads status 
		values_modes[COMFORT][CAR] <- min([1,speed_limit/50]);  // depends on speed limit
		values_modes[SAFE][CAR] <- 1-accident_rate; 	// depends on accident rate
		
		// bicycle
		//values_modes[ECOLO][BICYCLE] <- 1.0;	// always max
		values_modes[EASY][BICYCLE] <- avg_fitness;		// always easy? hilliness?
		//values_modes[TIME][BICYCLE] <- 0.8;		// always good? depends a bit on congestion? on hills? on fitness
		//values_modes[PRICE][BICYCLE] <- 0.1;    // always gratis
		values_modes[COMFORT][BICYCLE] <- max([0,(1-indic_pollution)*weather]);    // depends on hills, length of trip, age of people, pollution
		values_modes[SAFE][BICYCLE] <- mean([1-accident_rate,cycling_infrastructure]); // depends on cycling lanes ; accidents against bikes
		
		// walk
		//values_modes[ECOLO][WALK] <- 1.0;		// always ecolo
		values_modes[EASY][WALK] <- avg_fitness; 		// always easy
		//values_modes[TIME][WALK] <- 0.1;		// always very slow
		//values_modes[PRICE][WALK] <- 1.0;		// always gratis
		values_modes[COMFORT][WALK] <- 0.01*indic_trees + weather; 	// depends on trees and weather and carparks
		values_modes[SAFE][WALK] <- town_safety;		// depends on accidents against pedestrians? + town safety (cameras etc)
		
		// bus
		//values_modes[ECOLO][BUS] <- 0.8;		// depends on bus capacity (the higher the best) 
		values_modes[EASY][BUS] <- percent_close_bus; 		// depends on number of DENSITY transfers, frequency, number of stops...
		values_modes[TIME][BUS] <- bus_frequency;			// depends on FREQUENCY , distance to stop...
		values_modes[PRICE][BUS] <- max([0,1-bus_price]);		// depends on ticket/rego price
		values_modes[COMFORT][BUS] <- 1-indic_bus_congestion; 		// depends on capacity and number of actual passengers
		values_modes[SAFE][BUS] <- town_safety;			// depends on town safety
	}
	
	

	
	// graph distrib of happiness / of scores / of modes
	reflex update_distrib {
		//map<string, list> testdistrib;
		//list<float> totest <- [1, 2, 4, 1, 2, 5, 10.0];
		//add gauss(100, 100) to: totest;
		happydistrib <- distribution_of(people collect each.happiness, 10, 0,1);
		//write (happydistrib);
		
		politicaldistrib <- distribution_of (people collect each.political_satisf,10,0,1);
		
		// compter les citoyens favorables à chaque candidat
		loop c over: candidates.values {
			votes[c] <- people count (each.candidate = c);
		}
		
	}
	
	// evaluate city on criteria based on mobility used by its citizen
	reflex eval_city {
		// valeur de la ville sur chaque critere
		// = moyenne sur les modes de transport, de la valeur de ce critère pondérée par le nombre d'usagers
		// ainsi une ville qui favorise un mode peu écolo (eg bcp de voitures), sera jugée peu écolo
		loop c over:criteria {
			city_criteria[c] <- 0;
			loop m over: transport_modes {
				city_criteria[c] <- city_criteria[c] + (people count (each.mobility_mode = m))*values_modes[c][m];	
			}
			city_criteria[c] <- (city_criteria[c] / length(people)) with_precision 2;	
		}
		loop m over: transport_modes {
			city_modes[m] <- 0;
			loop c over: criteria {
				city_modes[m] <- city_modes[m] + city_criteria[c]*values_modes[c][m];
			}
			city_modes[m] <- city_modes[m] / length(criteria);
			write("city modes map for debug");
			write(city_modes);
		}
	}
	
	
	
	// ********************************************
	// ***       BUDGET - BUDGET - KOPECS       ***
	// ********************************************
		
	// collect taxes
	action collect_budget {
		// get taxes from each citizen
		float plus <- tax_rate * length(people);
		write("Taxes: "+string(plus));
		budget <- budget + plus;
		
		// get petrol taxes 1% per each km travelled by car
		// warning: must be collected before resetting km travelled last year
		plus <- petrol_price * year_trips[CAR];
		write("Petrol taxes: "+string(plus));
		budget <- budget + plus;
		
		// tax car parking
		plus <- parking_price * 1.0 * year_trips[CAR];
		write("Carpark taxes: "+string(plus));
		budget <- budget + plus;
		
		// TODO: get some from bus km as well? could be a choice for the player: tax buses or not
		plus <- bus_price * year_trips[BUS];		
		write("Bus taxes: "+string(plus));
		budget <- (budget + plus) with_precision 0;
		
		write("Tax collected! New budget "+budget);
	}
	
	// yearly fees for the mayor
	action pay_costs {
		// prix d'entretien par bus (haute frequence coûte plus cher)
		float cost <- 10*bus_frequency;
		write("cost of buses "+string(cost));
		budget <- budget - cost;
		
		// prix d'entretien des routes? ou bien c'est une action volontaire
		cost <- 10*road_infrastructure;
		write("cost of roads "+string(cost));
		budget <- budget - cost;
	}
	
	
	
	// **********************************************
	// ***     INTERACTIVITY & PLAYER ACTIONS     ***
	// **********************************************
	
	// interactivity: management of buttons
	action init_buttons	{
		int inc<-0;
		int inc2<-0;
		// initialise action number associated with each button
		ask bouton {
			action_nb<-inc;
			inc<-inc+1;
			inc2<-inc2+1;
		}
	}
	
	// specify image and cost of each action
	// costs of actions - set in advance in a map here, or in the big switch
	// index = action_type (0-1-2-3 = title, 4-20 = actions)
	action init_actions{
		// ligne 1: boutons de titre - col 1 MONEY, col 2 BUILD, col 3 LEGAL, col 4 COMM
		add image_file(dossierImages +"dollar2.png") to: images;
		add image_file(dossierImages +"build1.png") to: images;
		add image_file(dossierImages +"redlight-triangle.jpg") to: images;
		add image_file(dossierImages +"comm.jpeg") to: images;
		
		// ligne 2: premiers boutons de chaque colonne (actions 3-4-5)
		add image_file(dossierImages +"petrol-price.jpeg") to: images;
		put 0  at: 4  in: actions_costs;  // change petrol price
		
		add image_file(dossierImages +"cycle-lane.png") to: images;
		put 10 at: 5  in: actions_costs;  // build cycling lane
		
		add image_file(dossierImages +"camera.png") to: images; // action 5
		put 7 at: 6  in: actions_costs;  // improve sefety
		
		add image_file(dossierImages +"ecolo.jpeg") to: images;
		put 1 at: 7 in: actions_costs;
		
		// ligne 3
		add image_file(dossierImages +"taxrate.png") to: images; // action 6 change tax rate
		put 0  at: 8  in: actions_costs;  // taxrate
		
		add image_file(dossierImages +"arbre.jpeg") to: images;
		put 2  at: 9  in: actions_costs;  // plant trees
		
		add image_file(dossierImages +"speed-limit.png") to: images;
		put 1  at: 10  in: actions_costs; 
		
		add image_file(dossierImages +"secu-routiere.jpeg") to: images;
		put 1 at: 11 in: actions_costs;
		
		// ligne 4
		add image_file(dossierImages +"bus-ticket.jpeg") to: images;
		add image_file(dossierImages +"repair-roads.png") to: images; // action 13
		put 4  at: 13 in: actions_costs;  // repair road
		
		add image_file(dossierImages +"bus-capacity.png") to: images;
		put 6 at: 14 in: actions_costs;
		
		add image_file(dossierImages +"blanc.png") to: images;
		// change habits: ask some people to drop their habits, among those who use cars?
		
		// ligne 5
		add image_file(dossierImages +"no-car.png") to: images;
		
		//add image_file(dossierImages +"roadwork.png") to: images; // action 17
		add image_file(dossierImages +"carpark.jpeg") to: images; // action 8
		put 5  at: 17  in: actions_costs;  // allow carpark somewhere
		
		// repair all roads: cost depends on number of roads
		
		add image_file(dossierImages +"bus-frequency.png") to: images;
		add image_file(dossierImages +"blanc.png") to: images;
		
		// ligne 6
		add image_file(dossierImages +"blanc.png") to: images;
		add image_file(dossierImages +"blanc.png") to: images;
		add image_file(dossierImages +"bus-stop.png") to: images; // action 22
		put 20 at: 22 in: actions_costs;  // add bus stop
		
		add image_file(dossierImages +"blanc.png") to: images;
		
		// ligne 7
		add image_file(dossierImages +"blanc.png") to: images;
		add image_file(dossierImages +"blanc.png") to: images; // pas d'action ici
		add image_file(dossierImages +"blanc.png") to: images;
		add image_file(dossierImages +"blanc.png") to: images;	
	}
	
	// all possible actions, with budget, and effect on values
	// TODO : XML file for description of the actions?
	// prevent actions when impossible, and do not deduce budget in that case !
	action activate_act {
		list<bouton> selected_but <- bouton overlapping (circle(1) at_location #user_location);
		ask selected_but {action_type<-action_nb;
			bord_col<-#yellow;
			ask bouton {if bouton!=myself {bord_col<-#black;}}
		}
	
		// fail if no budget
		//actions_costs[13] <- actions_costs[10]*length(road where (each.status < 1.0));
		if actions_costs[action_type] > budget {
			write("FAIL: this action costs "+actions_costs[action_type]+" but you only have "+budget+" budget left");
		}
		// if already maximal: do nothing either, at no cost
		// case when it works
		else {
			//bool done_action <- false;
		
			// giant SWITCH action_type TODO une fois les actions codées
			switch action_type {
				match 0 {write("In this columns are actions to modify prices or use monetary incentives. \n Your budget = "+budget);}
				match 1 {write("In this column are actions to build new infrastructures or modify existing ones");}
				match 2 {write("In this column you find actions that change laws and regulations in your town");}
				match 3 {write("In this colum are actions to communicate with the population");}
			
				// PRICES
				match 4 { do change_petrol_price; }
				match 8 { do change_tax_rate; }
				match 12 { do change_bus_price; }
				match 16 { do forbid_old_cars; }
				match 20 { do tax_carpark;}
				match 24 {write("PRICES - Action 6");}			
				
				// INFRASTRUCTURES
				match 5 { do build_cycling_lane; }
				match 9 { do plant_trees; }
				match 13 { do repair_road; }
				match 17 { do build_carpark; }
				match 21 {write("BUILD - Action 5");}
				match 25 {write("BUILD - Action 6");}
			
				// REGULATIONS
				match 6  { do improve_town_safety; }
				match 10 { do change_speed_limit; } 
				match 14 { do change_bus_frequency; }
				match 18 { do increase_bus_capacity; }
				match 22 { do add_bus_stop; }
				match 26 { write("REGULATION - action 6"); }
				
				// COMMUNICATION
				match 7 { do communicate_ecology; }	
				match 11 { do communicate_roadsafety; }
				match 15 {write("COMM - Change habits?");}
				match 19 {write("COMM - action 4");}
				match 23 {write("COMM - action 5");}
				match 27 {write("COMM - action 6");}
			}
			
			// deduce budget if and only if action was performed indeed
			//if (done_action) {
			budget <- budget - actions_costs[action_type];
			write("*** Budget = "+budget);
			//}		
		}//end if budget sufficient
	}//end activate_act
		
	
	// individual actions that will be called by the big match in activate_act
	
	// change petrol price (that goes into budget)
	action change_petrol_price {
		write("PRICES - Change petrol price");
		write ("Current petrol price : "+(petrol_price)+"$");
		float old <- petrol_price;
		// read user input for new tax rate		
		map input_values <- user_input(["Petrol price (in $)"::(petrol_price)]);
		// update president with new tax rate from user input
		petrol_price <- float(input_values["Petrol price (in $)"]);
		// user feedback in console
		write ("New petrol price "+(petrol_price)+"$");
		// new value of criteria for price obtained as a ratio of the price increase/decrease
		values_modes[PRICE][CAR] <- min([1,values_modes[PRICE][CAR] * old / petrol_price]) with_precision 2;
	}
	
	action change_tax_rate {
		write("PRICES - Change tax rate");
		write ("Previous tax rate : "+(tax_rate)+"%");
		// read user input for new tax rate		
		map input_values <- user_input(["Tax rate (in %)"::(tax_rate)]);
		// update president with new tax rate from user input
		tax_rate <- float(input_values["Tax rate (in %)"]);
		// user feedback in console
		write ("New tax rate "+(tax_rate)+"%.");
		// change resulting satisfaction of population --> considered in political satisfaction
	}

	action change_bus_price {
		write("PRICES - Bus ticket price");
		// read user input for new bus ticket price
		string msg <- "Bus ticket price";
		map input_values <- user_input([msg::(bus_price)]);
		// update president with new tax rate from user input
		bus_price <- float(input_values[msg]);
		// user feedback in console
		write ("New bus price "+(bus_price)+"");
	}

	action forbid_old_cars {
		write("PRICES - Forbid old cars");
		// to check how accessibility of town evolves
		// TODO select people with lower budget - allow them an action to change car if theirs is too old
		ask 300 among (people where (each.has_car)) {
			has_car <- false; // cannot use the car anymore
		}
	}

	action add_bus_stop {
		write("CODE - Add bus stop");
		// TODO : augmenter directement le percent_close_bus (ou bien le nommer bus_cover)
		// TODO: pour l'instant cette variable nb_bus_stops n'a aucun impact nulle part...
		nb_bus_stops <- nb_bus_stops + 1; // will increase density hence practicity, time
										
		// some agents now gain a closer bus stop (about the population of one cell)
		// attention il y a moins de people que de cells... (1000 contre 2500)
		ask 10 among (people where ( not each.has_close_bus)) {
			has_close_bus <- true;
		}
	}
	
	action increase_bus_capacity {
		// FIXME can we reduce bus capacity? any change costs money anyway to reorganize buses
		write("CODE - Bus capacity");
		// read user input for new bus capa
		string msg <- "Bus capacity (in people)";
		int old_capa <- bus_capacity;	
		map input_values <- user_input([msg::(bus_capacity)]);
		bus_capacity <- int(input_values[msg]);
		// if actually changed something
		if old_capa != bus_capacity {
			//actions_costs[14] <- 6;
			// user feedback in console
			write("New bus capacity : "+bus_capacity) color: #blue;
			return true;
		}
		else {
			return false;
		}
	}
	
	// TODO could decrease it if max !
	action change_bus_frequency {
		write("CODE - Bus frequency");
		//if (bus_frequency < 1) {
			float old_freq <- bus_frequency;
			// read user input for new bus freq
			string msg <- "Bus frequency (in %)";
			map input_values <- user_input([msg::(bus_frequency)]);
			bus_frequency <- float(input_values[msg]);
						
			// does the player lose or gain budget ?
			if (bus_frequency > old_freq) {
				actions_costs[11] <- 50 * (bus_frequency - old_freq);
				write("Increased bus frequency : "+bus_frequency) color: #blue;
			}
			else if (bus_frequency < old_freq) {
				actions_costs[11] <- -50 * (old_freq - bus_frequency);
				write("Decreased bus frequency : "+bus_frequency) color: #blue;
			}
			else {
				// the player did not change the frequency
				actions_costs[11] <- 0;
				write("No change in bus frequency : "+bus_frequency) color: #blue;
			}					
		//}
	}
	
	// TODO different types: lane, paint on road/sidewalk, with different costs but different impacts on security
	action build_cycling_lane {
		write("BUILD - Build cycling lane");
		cycling_infrastructure <- cycling_infrastructure + 1;
		// cancel budget decrease (will be done per each cell clicked)
		//budget <- budget + actions_costs[action_type];
		// budget will just not be deduced since nothing was done
	}
	
	// TODO needs space, taken away from parking
	action plant_trees {
		write("BUILD - Plant trees");
		indic_trees <- indic_trees + 1;
		// cancel budget decrease (will be done per each cell clicked)
		//budget <- budget + actions_costs[action_type];
	}
	
	// TODO : il n'y aura plus de species road, c'est un niveau général de dégâts qu'il faut améliorer
	// avec un coût par point de dégât	
	action repair_road {
		write("BUILD - repair roads");
		avg_damage <- avg_damage -1;
		if avg_damage < 0 {avg_damage <- 0.0;}
	}
	
	// NOT CALLED yet (no button)
	action build_road {
		write("BUILD - build new road for cars");
		road_infrastructure <- road_infrastructure + 1;
	}
	
	// TODO could decrease it ? if not paying for it. For now decreases over time, so must pay regularly
	action improve_town_safety {
		write("CODE - Improve safety");
		//values_modes[SAFE][WALK] <- min([1,values_modes[SAFE][WALK] * 1.1]) with_precision 2;
		//values_modes[SAFE][BUS] <- min([1,values_modes[SAFE][BUS] * 1.1]) with_precision 2;
		//budget <- budget - 7;
		if town_safety < 1.0 {
			town_safety <- town_safety + 0.1 with_precision 2;
		}
		else {
			write("Safety is already maximal in your town");
		}
	}
	
	action build_carpark {
		// build car park: TODO
		write("CODE - Build carparks (Action 8 : TODO)");
		
		if indic_trees >= 10 {
			indic_trees <- indic_trees - 10;
			indic_carpark <- indic_carpark + 0.1;
		}
		else {
			// fail
		}		
		// TODO: must cut some trees
	}
	
	action tax_carpark {
		write("MONEY - Tax carparks");
		
		// read user input for new bus capa
		string msg <- "New parking price?";
		map input_values <- user_input([msg::(parking_price)]);
		parking_price <- int(input_values[msg]);
		
		// TODO : increase mayor's budget based on number of cars
		//        decreases indiv budget of car drivers 
	}
	
	action communicate_ecology {
		write ("Communicate about ecology");
	}
	
	action communicate_roadsafety {
		write ("Communicate about road safety");
	}
	
	action change_speed_limit {
		write("Change speed limit in town");
		string msg <- "New speed limit?";
		map input_values <- user_input([msg::(speed_limit)]);
		speed_limit <- int(input_values[msg]);
		
		accident_proba <- min([1,accident_proba * speed_limit/30]);
	}
	
	// ************************************************
	// ***  INTERACTING WITH POPULATION PRIORITIES  ***	
	// ************************************************
	
	// any actions from the player via the buttons do change the values of the criteria
	// these actions change the priorities of the criteria
	// they could actually be communication actions also available from the GUI
	// What we want to show: just changing the town has no impact if there is no change in priorities
	// probably the reset of habits is also a reset of priorities when something changes
	
	user_command set_prio_ecolo {
		map input_values <- user_input(["Priority of ecology"::0.5]);
		ask people {
			prio_criteria[ECOLO] <- int(input_values["Priority of ecology"]);
		}
	}
	
	user_command set_prio_money {
		map input_values <- user_input(["Priority of price"::0.5]);
		ask people {
			prio_criteria[PRICE] <- int(input_values["Priority of price"]);
		}
	}
	
	user_command set_prio_safety {
		map input_values <- user_input(["Priority of safety"::0.5]);
		ask people {
			prio_criteria[SAFE] <- int(input_values["Priority of safety"]);
		}
	}
	
	user_command set_prio_easy {
		map input_values <- user_input(["Priority of practicality"::0.5]);
		ask people {
			prio_criteria[EASY] <- int(input_values["Priority of practicality"]);
		}
	}
	
	user_command set_prio_comfort {
		map input_values <- user_input(["Priority of comfort"::0.5]);
		ask people {
			prio_criteria[COMFORT] <- int(input_values["Priority of comfort"]);
		}
	}
	
	user_command set_prio_time {
		map input_values <- user_input(["Priority of time"::0.5]);
		ask people {
			prio_criteria[TIME] <- int(input_values["Priority of time"]);
		}
	}
	
	
	// *************************
	// ***  GAME MANAGEMENT  ***	
	// *************************
			
	// normal turn = one year
	reflex newTurn when: cycle < 100 {
		write("-------\n Year "+cycle);

		// collect budget from taxes every year
		// to do before resetting counters (uses km by car / bus to perceive petrol taxes)
		do collect_budget;
		do pay_costs;
		
		// update indicators, and resulting values of the criteria for each mode
		do update_indicators;
		do update_values_modes;   // based on indicators

		// reset count of accident at the start of the year
		//ask road {accident_count <- 0;}

			
		// population actions 
		// TODO play an entire year with a loop of 365 citizens trips
		//      citizens_behaviour represents one day (simplified to one trip)
		// TODO distinguish week days and week-ends
		//loop i from: 1 to: 1 { // TODO 52 weeks
		//write("week "+i);
		
		write("Population is doing their trips...");
		ask people {do citizens_behaviour;}
		//}		
		// pause for player's actions
		do pause;
		write("Select your actions then press PLAY (green arrow)");
		write("Available budget : "+budget) color: #red;			
	}	
	
	// last turn
	reflex end_game when: cycle = 100 {
		// one last update
		do update_indicators;
		do update_values_modes;   // based on indicators
		
		write("Game over!");
		do pause;
	}
		
}//end global




//Species to represent the people using the skill moving
// TODO 2 JULY store past mobility modes, with score, over past years
species people skills: [moving]{
	//Target point of the agent
	point target;
	//Probability of leaving the building = PARAMETER
	//float leaving_proba <- move_proba; //0.05; 
	
	// TODO: gender et age non pertinents, extrapolés en liste des priorités?
	
	// TODO budget par agent pour déterminer prio du prix?
	
	// Speed of the agent
	float speed <- 5 #km/#h;
	rgb color <- rnd_color(255);
	
	// pour test graph histog distrib
	float age <- gauss(40.0, 15.0);
	
	// budget gaussian
	float budget <- gauss(100.0, 40.0);
	
	int mobility_mode; // among: [BICYCLE, CAR, BUS, WALK];
	float happiness <- 0.77 min: 0.0 max: 1.0;
	bool happy; 
	float political_satisf <- 1.0 min: 0.0 max: 1.0;
	string candidate <- "Mayor Toto";
	
	// critères de décision (priorités)
	// 6 critères SAGEO: prix, temps, confort, sécurité, simplicité, écologie
	// only priority differs inter agents (comfort of the bike is the same for all but not as important for all)
	map<int,float> prio_criteria;
	map<int,float> notes_modes;
	
	// store history of happiness to allow comparison along the mandate of the mayor
	// stores : happiness (note du mode choisi) et happy (false: 0, true: 1), chaque année
	// might need: used mode (did it change over the mandate)
	map<int,list<float>> history_happiness;
	list<int> history_mobility <- [];  // UNUSED yet ?
	
	// habits = how often does the agent use each mode (FIXME: should depend on context?)
	map<int,int> trips_mode; 		// nb of trips per mode over time
	map<int,float> habits_modes;  	// increases when mode is used, reset sometimes
	
	// accidents in the past (TODO impact perception of safety? well-being?) not used yet
	//int accidents <- 0; // TODO store different counters for each mode (eg 0 accidents in car, 2 accidents on bike)
	
	// Constraints = available transports - parameterised proba
	bool has_bike;
	bool has_car;
	bool has_close_bus;
	// simulates any constraints preventing from walking (handicap, shop, kids, etc)
	// which also prevents from using bike or bus
	bool can_walk; 
	
	//bool is_stuck <- false; // update: (target!=nil and mobility_mode=0);
	
	// TODO liste des modes au fil du temps pour évaluer combien de fois l'individu prend un mode qu'il aime/pas
	
	// TODO add acquaintances (friends, family, colleagues) with their social influence
	//    + add social pressure (weigh their mode of transport with their charisma/influence on the individual)
	// goal = show that influencing opinion leaders has more effect
	
	// TODO add indiv budget
	// TODO add actions to buy car / newer car / bicycle...
	
	// initialisation
	init {
		// priority of criteria
		// TODO paramétrer la moyenne des priorités ou bien la calibrer sur enquêtes réelles
		// TODO certaines actions (sensibilisation, communication) doivent pouvoir modifier ces prios
		loop i over: criteria {
			prio_criteria[i] <- rnd(1.0);
		}
		
		// habits of modes - 
		// FIXME: individuals have an initial habitual mode? or start at 0? or param of scenario? 
		loop i over: transport_modes {trips_mode[i] <- 0; notes_modes[i]<-1.0;}
		trips_mode[0] <- 0;  // no mobility, cannot move
		
		mobility_mode <- -1;
		
		// initial constraints (probabilities defined as parameters)
		has_bike <- flip(percent_has_bike);
		has_car <- flip(percent_has_car);
		has_close_bus <- flip(percent_close_bus);
		// can always walk if has no other way to go
		can_walk <- flip(percent_can_walk) or (not has_bike and not has_car and not has_close_bus);
	}

	// mettre à jour la matrice de notes des modes de transport (moy pondérée des critères * prio)
	reflex update_notes {
		// static note of each mode (changes when global values_modes change (result of player's actions)
		loop i over: transport_modes {
			notes_modes[i] <- note_mode(i);
		}
	}
	
	
	// a chance to reset habits completely (= reset trip counts, otherwise habit is re-created immediately)
	// global proba for any agent to drop their habit at each time step (= year)
	// simulates changes in life cycle (new work, move house, baby...)
	reflex drop_habits when: flip(habit_drop_proba) {
		// FIXME reset counter of trips, or habit proba?
		loop i over: transport_modes {trips_mode[i] <- 0;}
	}
	
	// update habits each turn from count of trips
	// TODO : here, use sliding window to only consider most recent trips only?
	//      --> need to store list of last trip modes to be able to discard them after a while
	reflex update_habits {
		// sum of nb of trips per mode
		int s <- 0;
		loop m over: transport_modes {
			s <- s + trips_mode[m];
		}

		// % of trips done with this mode
		// the more trips there are, the less one additional trip changes anything
		loop i over: transport_modes {
			habits_modes[i] <- s>0? trips_mode[i] / s : 0.0;
		}		
	}
	
	// can the individual use a given transport mode
	bool can_use(int mode) {
		switch mode {
			// FIXME ONGOING 1 JULY - add can_walk constraint but check most people can still move...
			match BUS {return has_close_bus and can_walk;}  //  and can_walk
			match BICYCLE {return has_bike and can_walk;}  //  and can_walk
			match CAR {return has_car;}
			match WALK {return can_walk;} // depend on age?
			match 0 {return false;}
		}
	}
	
	
	// (rational) note of a given mode of transport
	// SIMPLIF: for now the values of a mode is static for all agents (kind of global average)
	// TODO : to be weighed by habit, emotions (eg fear of accidents), social pressure, constraints... (which are individual)
	float note_mode(int mode) {
		float note <- 0.0;
		loop c over: criteria {
			note <- note + values_modes[c][mode] * prio_criteria[c];
		}
		note <- note / sum(prio_criteria.values);
		
		return note with_precision 2;
	}

		
		
	/* ********* ACTION SELECTION - PEOPLE BEHAVIOUR **************** */	
		
	// behaviour of citizens coded in actions 
	// triggered when the player has finished doing their actions with their budget
	// (~ one representative day ?) TODO: week days vs week-ends + call in a year loop
	action citizens_behaviour {
		
		// time scale
		// il faudrait faire agir les people 365 fois (1 trip par jour sur un an)
		// avant de redonner la main au joueur pour l'année suivante
		// done 4 March 2022 : 200 choix de déplacement dans l'historique, mais 1 seule animation
		
		// FIXME: choose once for the year, or everyday?
		do choose_mode;
		// store in history for this year + TODO: also store score of this mode at that time
		add mobility_mode to: history_mobility;
		
		
		// SIMPLIF 29 MARCH: no moves, citizens only choose their mobility mode
		put [happiness, happy?1.0:0.0] at: cycle in: history_happiness;
	}	
	
	// preferred criteria (highest priority)
	int preferred_criteria {
		int pref_crit <- 1;
		loop i over: criteria {
			if prio_criteria[i] > prio_criteria[pref_crit] {
				pref_crit <- i;
			}
		}
		return pref_crit;
	}	

	// return rationnally preferred mode (independent from constraints)
	int preferred_mode {
		int index_pref <- 1;
		loop i over: transport_modes {
			if notes_modes[i] > notes_modes[index_pref] {
				index_pref <- i;
			}
		}
		return index_pref;
	}
	
	// returns selected mode = preferred among those that are possible (constraints)
	int selected_mode {
		// search preferred mode (index of max note)
		float max_note <- 0.0;
		int index_pref <- 0;
		loop i from: 1 to: 4 {
			// check constraints on usage
			if notes_modes[i] >= max_note and can_use(i) {
				index_pref <- i;
				max_note <- notes_modes[i];
			}
		}
		// if no transport mode is feasible, the agent cannot move (returns index_pref = 0)
		return index_pref;
	}
		
	// habitual mode = most used mode over the past
	// should be 0 if no trips yet !
	int habitual_mode {
		// search mode with highest habit coeff (or highest trip count)
		int m <- 0;
		float maxi <- 0.0;
		loop i from: 1 to: 4 {
			if habits_modes[i] > maxi {
				m<-i;
				maxi <- habits_modes[i];
			}
		}
		return m;
	}
			
	// action to choose mobility mode before leaving based on preference + constraints + habits
	// TODO also consider peer pressure
	action choose_mode {
		// flip routine coefficient for a chance to routinely take same mode as usual
		int hm <- habitual_mode();
		
		// chance to routinely select habitual mobility mode
		if hm > 0 and flip(habits_modes[hm]) and can_use(hm) {mobility_mode <- hm;}
		// otherwise rational choice is made
		else {
			// select mode with best note and usable
			mobility_mode <- selected_mode();
			//if (mobility_mode = 0) {write(""+self+" cannot move");}
		}
		
		// increase individual habit for this mode (even if = 0 : cannot move)
		trips_mode[mobility_mode] <- trips_mode[mobility_mode] + 1;
		// increase global number of trips only when starting the trip
		year_trips[mobility_mode] <- year_trips[mobility_mode] + 1;
		
		// set happiness - FIXME even if agent does not choose a mode ? always choose a mode, even if ends up null
		happiness <- mobility_mode=0?0.0:notes_modes[mobility_mode];    // how happy with the chosen mobility mode
		happy <- mobility_mode = preferred_mode();	// could he use the preferred mobility mode (vs constraints) 
	}	
		
	
	// NEW 29 MARCH 22 : removed mobility to simplify computation
	// need to compute pollution and accidents manually based on number of trips
	

	
	
	
	// ************************************************
	// ***       ELECTIONS - CHOOSE CANDIDATE       ***
	// ************************************************
	
	// measure political satisfaction after one mandate

	
	// pour les sondages
	reflex political_satisfaction {
		float ps <- 1.0;
		
		// critère le plus prioritaire
		int i <- preferred_criteria();
		// sa prio pour l'agent
		float j <- prio_criteria[i];
		// valeur de ce critère dans la ville actuelle / le maire actuel
		float k <-  city_criteria[i];
		if k<j {
			ps <- ps * (k/j) with_precision 2;
		}
		
		// ou mode de transport préféré - ou utilisé : mobility_mode
		int m <- preferred_mode();
		// vs valeur de ce mode dans la ville actuelle
		float nm <- notes_modes[m];
		ps <- ps * nm;
		
		// multiply by (1-totaltaxrate)
		/*float cost <- tax_rate*budget;
		if mobility_mode = CAR {
			cost <- cost + petrol_price*10;
		}
		else if mobility_mode = BUS {
			cost <- cost + bus_price;
		}
		cost <- min([cost,100]);
		// TODO negative costs if incitations to use bicycle/walk
		ps <- ps * (100-cost)/100;		
		write("ps4 costs "+string(ps));
		*/
		
		ps <- ps * (1-tax_rate/100);
		//write("tax rate "+string(tax_rate));
		
		// vote (at each turn for polls shown in GUI)
		political_satisf <- ps;
		
		//write("political satisf "+string(ps));
		
		if political_satisf > 0.7 {candidate <- candidates[0];}
		else {candidate <- candidates[i];}
		
		//write("political satisfaction");
		//write(city_criteria);
	}
	

	
	
	// ***************************************************
	// ***       VISUALISATION OF CITIZENS ON MAP      ***
	// ***************************************************
	
	// TODO draw with a gif shape + color depending on selected mobility mode
	// TODO another aspect to show happiness with a color
	aspect default {draw circle(5) color: color;}
}//end species people







/* ******************************************************************
 *******    BOUTONS                                   ***
*********************************************************************/
grid bouton width:4 height:7 
{
	int action_nb;
	float img_h <-world.shape.height/8;
	float img_l <-world.shape.width/5;
	rgb bord_col<-#black;

	aspect normal {
		draw images[action_nb] size:{img_l/2,img_h/2};
	}
}



experiment play type: gui {
	float minimum_cycle_duration <- 0.01;
 	
	// parameters of the simulator
	//parameter "Moving proba" init: 0.5 min: 0.0 max: 1.0 var: move_proba category: "Parameters";
	
	// PREVIOUS PARAMS - not selected as parameters but as part of pedagogical scenario
	//parameter "Road degrading" init: 0.1 min: 0.0 max: 1.0 var: roads_degrade_speed category: "Environment";
	//parameter "Accident proba" init: 0.1 min: 0.0 max: 1.0 var: accident_proba category: "Environment";
	//parameter "Weather comfort" init: 0.5 min: 0.0 max: 1.0 var: weather category: "Environment";
	//parameter "Habit drop proba 0-1" init: 0.05 min: 0.0 max: 1.0 var: habit_drop_proba category: "Population";
	
	// Population
	parameter "Average population fitness" init: 0.5 min: 0.0 max: 1.0 var: avg_fitness category: "Population";
	parameter "Who has a bike (%)" init: 0.7 min: 0.0 max: 1.0 var: percent_has_bike category: "Population";
	parameter "Who has a car (%)" init: 0.9 min: 0.0 max: 1.0 var: percent_has_car category: "Population";
	parameter "Who has a bus stop (%)" init: 0.5 min: 0.0 max: 1.0 var: percent_close_bus category: "Population";
	parameter "Who can walk (%)" init: 0.2 min: 0.0 max: 1.0 var: percent_can_walk category: "Population";
	// TODO population size?
	
	output {
 		//layout horizontal([vertical([0::5676,1::4324])::3107,vertical([horizontal([2::5000,3::5000])::3859,4::6141])::6893]) tabs:true editors: false;
		//layout #horizontal;

		//Boutons d'action
		display action_button name:"Actions possibles" ambient_light:100 	{
//			grid bouton triangulation:false size:{0.5,0.5} position: {0,0};
			species bouton aspect:normal ;
			event mouse_down action:activate_act;    
		
		}
		// written indicators
		display indicateurs name:"Indicateurs" ambient_light:100 {	// 200 #px, 180 #px 
    		graphics position:{ 0, 0 } size:{ 1,1} { // overlay background:#white rounded:true   transparency:1     {
        		//indicateurs
			    draw "Valeurs des indicateurs en année "+cycle at:{ 20#px, 20#px } color:rgb(34,64,139) font:font("SansSerif", 14, #bold);
     			rgb col <-#black;
        		float top;
        		int m;
        		
			    draw  'Population : '+length(people) at:{ 30#px, 30#px } color:#black font:font("SansSerif", 12, #bold);
				draw  'Budget : '+budget at: {150#px, 30#px} color: #orange;
				
				// FIXME how to factorise code
				col <- #green;
				top <- 50 #px;
				m <- BICYCLE;
				draw 'Bicycle : '+(people mean_of each.notes_modes[BICYCLE] with_precision 2) at: {30#px, top} color: col font:font("SansSerif", 12, #bold);
				draw '  - Ecology : '+values_modes[ECOLO][m] with_precision 2 at: {40#px, top+10#px} color: col;
				draw '  - Price : '+values_modes[PRICE][m] with_precision 2 at: {40#px, top+20#px} color: col;
				draw '  - Comfort : '+values_modes[COMFORT][m] with_precision 2 at: {40#px, top+30#px} color: col;
				draw '  - Safe : '+values_modes[SAFE][m] with_precision 2 at: {40#px, top+40#px} color: col;
				draw '  - Easy : '+values_modes[EASY][m] with_precision 2 at: {40#px, top+50#px} color: col;
				draw '  - Fast : '+values_modes[TIME][m] with_precision 2 at: {40#px, top+60#px} color: col;
				
				col <- #red;
				top <- 130 #px;
				m <- CAR;
				draw 'Car : '+(people mean_of each.notes_modes[CAR] with_precision 2) at: {30#px, top} color: col font:font("SansSerif", 12, #bold);
				draw '  - Ecology : '+values_modes[ECOLO][m] with_precision 2 at: {40#px, top+10#px} color: col;
				draw '  - Price : '+values_modes[PRICE][m] with_precision 2 at: {40#px, top+20#px} color: col;
				draw '  - Comfort : '+values_modes[COMFORT][m] with_precision 2 at: {40#px, top+30#px} color: col;
				draw '  - Safe : '+values_modes[SAFE][m] with_precision 2 at: {40#px, top+40#px} color: col;
				draw '  - Easy : '+values_modes[EASY][m] with_precision 2 at: {40#px, top+50#px} color: col;
				draw '  - Fast : '+values_modes[TIME][m] with_precision 2 at: {40#px, top+60#px} color: col;
				
				col <- #blue;
				top <- 210 #px;
				m <- BUS;
				draw 'Bus : '+(people mean_of each.notes_modes[BUS] with_precision 2) at: {30#px, top} color: col font:font("SansSerif", 12, #bold);
				draw '  - Ecology : '+values_modes[ECOLO][m] with_precision 2 at: {40#px, top+10#px} color: col;
				draw '  - Price : '+values_modes[PRICE][m] with_precision 2 at: {40#px, top+20#px} color: col;
				draw '  - Comfort : '+values_modes[COMFORT][m] with_precision 2 at: {40#px, top+30#px} color: col;
				draw '  - Safe : '+values_modes[SAFE][m] with_precision 2 at: {40#px, top+40#px} color: col;
				draw '  - Easy : '+values_modes[EASY][m] with_precision 2 at: {40#px, top+50#px} color: col;
				draw '  - Fast : '+values_modes[TIME][m] with_precision 2 at: {40#px, top+60#px} color: col;
				
				col <- #pink;
				top <- 290 #px;
				m <- WALK;
				draw 'Walking : '+(people mean_of each.notes_modes[WALK] with_precision 2) at: {30#px, top} color: col font:font("SansSerif", 12, #bold);
				draw '  - Ecology : '+values_modes[ECOLO][m] with_precision 2 at: {40#px, top+10#px} color: col;
				draw '  - Price : '+values_modes[PRICE][m] with_precision 2 at: {40#px, top+20#px} color: col;
				draw '  - Comfort : '+values_modes[COMFORT][m] with_precision 2 at: {40#px, top+30#px} color: col;
				draw '  - Safe : '+values_modes[SAFE][m] with_precision 2 at: {40#px, top+40#px} color: col;
				draw '  - Easy : '+values_modes[EASY][m] with_precision 2 at: {40#px, top+50#px} color: col;
				draw '  - Fast : '+values_modes[TIME][m] with_precision 2 at: {40#px, top+60#px} color: col;
				
				// indicateurs globaux
				float d <- 150 #px;
				//draw "Global indicators" at: {d, 30#px} color: #black;
				draw " - Quality of traffic "+indic_circulation*100+ " %" at: {d, 60#px} color: #black;
				draw " - Air pollution "+indic_pollution*100+ " %" at: {d, 80#px} color: #black;
				draw " - % of cycling lanes on roads "+100*cycling_infrastructure + " %" at: {d, 100#px} color: #black;
				draw " - Number of trees " + indic_trees at: {d, 120#px} color: #black;
				draw " - "+ world.nb_trips_year() + " trips" at: {d, 140#px} color: #black; // over "+ world.nb_km_year()+" km
				draw " - "+nb_roads_damaged+" roads damaged ("+avg_damage+"% damage avg)" at: {d, 160#px} color: #red;
				draw " - Accident rate : "+accident_rate with_precision 2 at:{d,180#px} color: #red;
				draw " - Town safety : "+town_safety at: {d,200#px} color: #blue;
				draw " - Bus density : "+percent_close_bus*100+" %" at: {d, 220#px} color: #blue;
				draw " - Pop happiness : "+indic_happiness at: {d, 240#px} color: #green;				
				draw " - Pop happy % : "+indic_happy at: {d, 260#px} color: #green;
				draw " - Accessibility % : "+(indic_accessibility*100)+" %" at: {d, 280#px} color: #pink;
				
				// priorités
				d <- 400 #px;
				draw "Prio ecology "+people mean_of each.prio_criteria[ECOLO] at: {d, 60#px} color: #green;
				draw "Prio price " +people mean_of each.prio_criteria[PRICE]  at: {d, 80#px} color: #orange;
				draw "Prio comfort " + people mean_of each.prio_criteria[COMFORT]  at: {d, 100#px} color: #blue;
				draw "Prio safety " + people mean_of each.prio_criteria[SAFE] at: {d, 120#px} color: #red;
				draw "Prio simplicity " + people mean_of each.prio_criteria[EASY] at: {d, 140#px} color: #blue;
				draw "Prio time " + people mean_of each.prio_criteria[TIME] at: {d, 160#px} color: #orange;
				
				// evaluation de la ville
				draw "City ecology "+city_criteria[ECOLO] color:#pink at: {d, 200#px} ;
				draw "City price "+city_criteria[PRICE] color:#pink at: {d, 220#px} ;
				draw "City comfort "+city_criteria[COMFORT] color:#pink at: {d, 240#px} ;
				draw "City safety "+city_criteria[SAFE] color:#pink at: {d, 260#px} ;
				draw "City simplicity "+city_criteria[EASY] color:#pink at: {d, 280#px} ;
				draw "City time "+city_criteria[TIME] color:#pink at: {d, 300#px} ;
				
				// usage of mobility modes
				float l <- 320 #px;
				draw "% bicycles "+(people count (each.mobility_mode=BICYCLE))/length(people) with_precision 2 color:#green at: {d, l};
				l <- l+20 #px;
				draw "% cars "+(people count (each.mobility_mode=CAR))/length(people) with_precision 2 color:#red at: {d, l};
				l <- l+20 #px;
				draw "% bus "+(people count (each.mobility_mode=BUS))/length(people) with_precision 2 color:#blue at: {d, l};
				l <- l+20 #px;
				draw "% walk "+(people count (each.mobility_mode=WALK))/length(people) with_precision 2 color:#purple at: {d, l};
				
       		}//end graphics
		}//end display indicators	
		
	    display "Mobility" {
    	    // affiche la note moyenne sur la population de chaque mode de transport
    	    chart "POP MODES" size:{0.5,0.5} position:{0,0} type: radar background: #white axes:#black 
    	    x_serie_labels: ["ecolo", "cheap", "comfort", "safe","easy","fast"] series_label_position: xaxis {
    	   		data "bicycle"   value: values_modes.values collect (each[BICYCLE]) color:#green; //  [x][BICYCLE]    color: #green; // accumulate_values: true;
    	   		data "car" value: values_modes.values collect(each[CAR]) color: #red;
    	   		data "bus" value: values_modes.values collect(each[BUS]) color: #blue;
    	   		data "walk" value: values_modes.values collect(each[WALK]) color: #pink;
    	   		//data "Bicycle" value:[values_modes[x][BICYCLE],values_modes[x][BICYCLE],values_modes[x][BICYCLE],values_modes[x][BICYCLE],values_modes[x][BICYCLE],values_modes[x][BICYCLE]] color:#green;
       		}// end chart
       		
       		// radar chart evaluation de la ville sur les 6 critères
   	    	chart "CITY" type: radar  size:{0.5,0.5} position:{0.5,0}  background: #white axes:#black 
		    	    x_serie_labels: ["ecolo", "cheap", "comfort", "safe","easy","fast"] series_label_position: xaxis {
    			   		data "city"  color:#purple //  value: city_criteria.values  
    			   		value: [city_criteria[ECOLO],city_criteria[PRICE],city_criteria[COMFORT],city_criteria[SAFE],city_criteria[EASY],city_criteria[TIME]];
       		}// end chart
       		
       		// radar chart evaluation de chaque mode de transport sur la ville
       		chart "CITY MODES" type: radar size: {0.5,0.5} position: {0.5,0.5} series_label_position: xaxis
       			x_serie_labels: ["bike","walk","car","bus"] {
       				data "city" value: [city_modes[BICYCLE], city_modes[WALK], city_modes[CAR], city_modes[BUS]] color: #purple;
       			}
       		
       		chart "TRIPS"  size: {0.5,0.5} position: {0, 0.5} type:pie
			{
				//int paf <- sum(year_trips.values)=0?1:sum(year_trips.values);
				data "bicycle" value:year_trips[BICYCLE] color:°green;
				data "car" value:year_trips[CAR] color:°red;
				data "bus" value:year_trips[BUS] color:°blue;
				data "walk" value:year_trips[WALK] color:°yellow;
			}
       	} // end display radars
       	
    	// un radar chart avec les prios des 6 critères en moyenne dans la population
    	display "Population" {
    		//  size: {0.5,0.5} position: {0, 0}
    		
       		chart "HAPPINESS" type: histogram size: {0.5,0.5} position: {0, 0}
			{
				datalist list(happydistrib at "legend") value: list(happydistrib at "values");
			}
        	
    	    chart "PRIORITIES" type: radar background: #white axes:#black size: {0.5,0.5} position: {0.5, 0}
    	    	x_serie_labels: ["ecolo", "cheap", "comfort", "safe","easy","fast"] 
    	    	series_label_position: xaxis {
    	   			data "avg"   value: [people mean_of each.prio_criteria[ECOLO], people mean_of each.prio_criteria[PRICE],
    	   				people mean_of each.prio_criteria[COMFORT],people mean_of each.prio_criteria[SAFE],
	   					people mean_of each.prio_criteria[EASY],people mean_of each.prio_criteria[TIME]
    	   			] color:#green;
    	   			// values_modes.values collect (each[BICYCLE]
       		}// end chart
       		
       		chart "MODES SCORES" type: histogram size: {0.5,0.5} position: {0,0.5}
       			{
       				datalist ["walk","bicycle","bus","car"] value: [ (people mean_of each.notes_modes[WALK]) with_precision 2, 
       											(people mean_of each.notes_modes[BICYCLE]) with_precision 2,
       											(people mean_of each.notes_modes[BUS]) with_precision 2, 
       											(people mean_of each.notes_modes[CAR]) with_precision 2
       				];
       			} //end chart       			
       		
       		chart "Happiness per mode" type: histogram size:{0.5,0.5} position: {0.5,0.5}
       		{
       			datalist ["walk","bicycle","bus","car"] 
       			value: [ (people where (each.mobility_mode=WALK)) mean_of each.happiness,
       						(people where (each.mobility_mode=BICYCLE)) mean_of each.happiness,
       						(people where (each.mobility_mode=BUS)) mean_of each.happiness,
       						(people where (each.mobility_mode=CAR)) mean_of each.happiness
       			] ;
       		}
       		
       		/*chart "MODES SCORES" type: radar //background: #white axes: #black size: {0.5,0.5} position: {0,0.5}
       			x_serie_labels: ["walk","bicycle","bus","car"]
       			series_label_position: xaxis  size: {0.5,0.5} position: {0.5,0.5}
       			{
       				data "avg score" value: 
       				[ (people mean_of each.notes_modes[WALK]) with_precision 2, 
       											(people mean_of each.notes_modes[BICYCLE]) with_precision 2,
       											(people mean_of each.notes_modes[BUS]) with_precision 2, 
       											(people mean_of each.notes_modes[CAR]) with_precision 2
       				] color: #blue;
       			} //end chart
       		*/
       	}// end display population
       	
       	display "Politics" {
       		chart "Satisfaction" type: histogram size: {0.5,0.5} position: {0, 0}
			{
				datalist list(politicaldistrib at "legend") value: list(politicaldistrib at "values");
			}
       		
       		// TODO un histogram sondage politique pour qui voteront les electeurs
       		chart "POLLS" type: histogram size: {0.5,0.5} position: {0,0.5}
       		{
       			datalist votes.keys value: votes.values;
       		}
       		
       		chart "Satisfaction per mode" type: histogram size:{0.5,0.5} position: {0.5,0.5}
       		{
       			datalist ["walk","bicycle","bus","car"] 
       			value: [ (people where (each.mobility_mode=WALK)) mean_of each.political_satisf,
       						(people where (each.mobility_mode=BICYCLE)) mean_of each.political_satisf,
       						(people where (each.mobility_mode=BUS)) mean_of each.political_satisf,
       						(people where (each.mobility_mode=CAR)) mean_of each.political_satisf
       			] ;
       		}
       		
       		
       	} // end display radars
       	
    	//display carte type: opengl {
		//	event mouse_down action:action_cell;  // what happens when clicking on a cell of the grid
			
		//	species building refresh: false;
		//	species road ;
		//	species people ;
			
			//display the pollution grid in 3D using triangulation.
		//	grid cell elevation: pollution * 3.0 triangulation: true transparency: 0.7; // lines: #black;
		
		//}//end display carte
    	

	}//end output
}//end expe
