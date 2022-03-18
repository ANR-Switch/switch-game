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
* Name: Traffic
* Author: Patrick Taillandier
* Description: A simple traffic model with a pollution model: the speed on a road depends on the number of people 
* on the road (the highest, the slowest), and the people diffuse pollution on the envrionment when moving.
* Tags: gis, shapefile, graph, skill, transport
*/

model switchlite

// TODO sliders pour les priorités moyennes des agents (pour favoriser la voiture)

// TODO simplified interface in a 2nd experiment
// TODO habits per context, weather, peak hour, etc? pas le thème de ce jeu, si ce n'est pour créer un peu d'inertie

// TODO calibrer les paramètres de la population (fitness, who has a bike, a car, a close bus stop)
//      d'après les stats INSEE, pour les supprimer des paramètres
// + calibrer les priorités d'après une survey?


// TODO
// - satisfaction dépend des impôts
// - priorité du critère prix dépend des impôts
// - afficher un pie chart des modes préférés des citoyens (qui utilisent p-e un mode non préféré)
// - plutôt qu'un pie chart, afficher le nombre de trajets et de km fait pour chaque mode
// - afficher un pie chart du mode habituel des citoyens (le plus de trajets sur les 200 de l'année)

// TODO doc : documenter l'ajout d'un bouton d'action

global {
	//Shapefile of the buildings
	file building_shapefile <- file("../includes/buildings2.shp");
	//Shapefile of the roads
	file road_shapefile <- file("../includes/roads.shp");
	//Shape of the environment
	geometry shape <- envelope(road_shapefile);
	//Step value
	float step <- 10 #s;
	//Graph of the road network
	graph road_network;
	//Map containing all the weights for the road network graph
	map<road,float> road_weights;
	
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
	float roads_degrade_speed;  // factor of road degradation over time
	float accident_proba;		// probability of accident (will be weighed by congestion)
	// weather (TODO rain yes/no, cold yes/no), or float value from -1 (desagreeable) to +1 (very agreeable)
	float weather <- 0.5 min: 0.0 max: 1.0;
	
	// PARAMETERS OF POPULATION
	float habit_drop_proba; 	//proba to reset habits
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
	// map de coût de chaque action 
	map<int,int> actions_costs;
	
	// INDICATORS - to be displayed in game interface
	// bouchons / taux d'utilisation des routes
	float indic_circulation <- 1.0 min: 0.01 max: 1.0; // update: (road mean_of each.speed_coeff);
	// pollution (augmentée par les voitures)
	float indic_pollution <- 0.0;   // update: 0.01 * (cell mean_of each.pollution) ;
	// % de routes équipées de pistes cyclables
	float indic_cyclability <- 0.0;
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
	
	// TODO add vitesse limite autorisée
	// add capacité des routes (selon que voies dédiées aux bus / vélos / voitures)
	
	// count of distance / trips per year / overall 
	map<int,int> total_km_travelled;
	map<int,int> year_km_travelled;
	map<int,int> year_trips;
	map<int,int> total_trips;
	
	// CRITERIA EVALUATION (GLOBAL FOR NOW)
	map<int,map<int,float>> values_modes;  // indice 1 = criteria, indice 2 = mode
	
	// INTERFACE - IMAGES ON BUTTONS
	string dossierImages <-  "../includes/imgs/" ;
	list<image_file> images <- [	// from sprite, 3 colonnes de 7 boutons	
		// ligne 1: boutons de titre - col 1 MONEY, col 2 BUILD, col 3 LEGAL
		image_file(dossierImages +"dollar2.png"),
		image_file(dossierImages +"build1.png"),
		image_file(dossierImages +"redlight-triangle.jpg"),
		
		// ligne 2: premiers boutons de chaque colonne (actions 3-4-5)
		image_file(dossierImages +"petrol-price.jpeg"),
		image_file(dossierImages +"cycle-lane.png"),
		image_file(dossierImages +"camera.png"), // action 5
		
		// ligne 3
		image_file(dossierImages +"taxrate.png"), // action 6 change tax rate
		image_file(dossierImages +"arbre.jpeg"),
		image_file(dossierImages +"carpark.jpeg"), // action 8
		
		// ligne 4
		image_file(dossierImages +"bus-ticket.jpeg"),
		image_file(dossierImages +"repair-roads.png"), // action 10
		image_file(dossierImages +"bus-capacity.png"),
		
		// ligne 5
		image_file(dossierImages +"no-car.png"),
		image_file(dossierImages +"roadwork.png"), // action 13
		image_file(dossierImages +"bus-frequency.png"),
		
		// ligne 6
		image_file(dossierImages +"blanc.png"),
		image_file(dossierImages +"blanc.png"),
		image_file(dossierImages +"bus-stop.png"), // action 17
		
		// ligne 7
		image_file(dossierImages +"blanc.png"),
		image_file(dossierImages +"blanc.png"), // pas d'action ici
		image_file(dossierImages +"blanc.png")
	]; 
	// which action was clicked in interface
	int action_type;
	
	
	// ************************
	// ***  INITIALISATION  ***
	// ************************
		
	init {
		// buttons with action number
		do init_buttons;
		do init_actions_costs;
		
		// init values of criteria for each mode (for now random)
		do init_values_modes;
		
		// static map of pollution per mode
		put 10 at: CAR in: pollution_modes;
		put 1 at: BUS in: pollution_modes;
		
		//Initialization of the building using the shapefile of buildings
		create building from: building_shapefile;

		//Initialization of the road using the shapefile of roads
		create road from: road_shapefile;
      	//Weights of the road
      	road_weights <- road as_map (each::each.shape.perimeter);
      	road_network <- as_edge_graph(road);
		
		//Creation of the people agents
		create people number: 100 {
			//People agents are located anywhere in one of the building
			location <- any_location_in(one_of(building));
      	}
      	
      	// density of bus stops per cell / per agent
      	nb_bus_stops <- int(length(cell) * percent_close_bus);
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
	
	// initialise counters of km / trips for each mode
	action init_indicators {
		loop i over: transport_modes {
			year_km_travelled[i] <- 0;
			total_km_travelled[i] <- 0;
			year_trips[i] <- 0;
			total_trips[i] <- 0;
		}
	}
	
	
	// *****************************
	// *** INDICATORS and UPDATE ***
	// *****************************
	
	// functions to sum total km / trips (to be called in graphics)
	int nb_km_year {
		int s <- sum(year_km_travelled.values);
		return s=0?1:s;
	}
	
	int nb_trips_year {
		int s <- sum(year_trips.values);
		return s=0?1:s;
	}

	// update indicators every (start of) year
	action update_indicators {
		
		// add km travelled last year and reset (even on last year)
		loop i over: transport_modes {		
			total_km_travelled[i] <- total_km_travelled[i] + year_km_travelled[i];
			year_km_travelled[i] <- 0;
			total_trips[i] <- total_trips[i] + year_trips[i];
			year_trips[i] <- 0;
		}
		
		indic_circulation <- (road mean_of each.speed_coeff) with_precision 2;
		indic_pollution <- 0.01 * (cell mean_of each.pollution) with_precision 2;
		indic_cyclability <- (road count each.cycle_lane) / length(road) with_precision 2;
		indic_trees <- (cell sum_of each.trees_on_cell);
		
		// damage
		nb_roads_damaged <- length(road where (each.status < 1));
		avg_damage <- (road mean_of each.status) with_precision 2;
		
		// accidents rate this year (count of accidents divided by number of km) (#trips too low)
		accident_rate <- (road sum_of each.accident_count) / nb_km_year();		
		
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
	}
	
	
	// reflex update_values_modes TODO remove modification in actions (indirect)
	// plutôt que le hardcoder dans les actions, il faut les recalculer
	// problème: on a 6 critères * 4 modes à calculer...
	action update_values_modes {
		// cars
		//values_modes[ECOLO][CAR] <- 0.0;  	// depends on pollution ?
		//values_modes[EASY][CAR] <- 1.0; 	// depends on parking
		values_modes[TIME][CAR] <- 1-indic_circulation ;	 	// depends on congestion, average duration of trips?
		values_modes[PRICE][CAR] <- max([0,1-petrol_price/2]); 	// petrol price and tax rate
		//values_modes[COMFORT][CAR] <- 1-avg_damage; 	// depends on roads status 
		values_modes[SAFE][CAR] <- 1-accident_rate; 	// depends on accident rate
		
		// bicycle
		//values_modes[ECOLO][BICYCLE] <- 1.0;	// always max
		values_modes[EASY][BICYCLE] <- avg_fitness;		// always easy? hilliness?
		//values_modes[TIME][BICYCLE] <- 0.8;		// always good? depends a bit on congestion? on hills? on fitness
		//values_modes[PRICE][BICYCLE] <- 0.1;    // always gratis
		values_modes[COMFORT][BICYCLE] <- (1-indic_pollution)*weather;    // depends on hills, length of trip, age of people, pollution
		values_modes[SAFE][BICYCLE] <- mean([1-accident_rate,indic_cyclability]); // depends on cycling lanes ; accidents against bikes
		
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
	
	
	// ******************************
	// *** ENVIRONMENT, POLLUTION ***
	// ******************************

	//Reflex to update the speed of the roads according to the weights
	// TODO : can we compute the time for each trip? to compare speed of different modes?
	reflex update_road_speed  {
		road_weights <- road as_map (each::each.shape.perimeter / each.speed_coeff);
		road_network <- road_network with_weights road_weights;
	}
	
	//Reflex to decrease and diffuse the pollution of the environment
	reflex pollution_evolution{
		//ask all cells to decrease their level of pollution
		ask cell {pollution <- pollution * 0.7;}
		
		//diffuse the pollutions to neighbor cells
		diffuse var: pollution on: cell proportion: 0.9 ;
	}
	
	
	// *****************************************
	// ***       ELECTIONS - NEW MAYOR       ***
	// *****************************************
	
	// organise election between the player and automated candidates (randomly picked in a pool?)
	action do_elections {
		// liste des noms des candidats
		list<string> candidates;
		// map des comptes de voix par candidat
		map<string,int> voices;
		
		// initialiser les voix à 0
		loop c over: candidates {
			voices[c] <- 0;
		}
		
		// faire voter les citoyens
		ask people {
			string voice <- vote(candidates);
			voices[voice] <- voices[voice] + 1;
		}
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
	
	// costs of actions - set in advance in a map here, or in the big switch
	// index = action_type (0-1-2 = title, 3-20 = actions)
	action init_actions_costs {
		// TODO 
		put 0  at: 3  in: actions_costs;  // change petrol price
		put 10 at: 4  in: actions_costs;  // build cycling lane
		put 7  at: 5  in: actions_costs;  // improve sefety
		put 0  at: 6  in: actions_costs;  // taxrate
		put 2  at: 7  in: actions_costs;  // plant trees
		put 5  at: 8  in: actions_costs;  // allow carpark somewhere
		put 4  at: 10 in: actions_costs;  // repair road
		put 8  at: 17 in: actions_costs;  // add bus stop
		// repair all roads: cost depends on number of roads
		// TODO 
	}
	
	// all possible actions, with budget, and effect on values
	// TODO : XML file for description of the actions?
	// TODO : prevent actions when impossible, and do not deduce budget in that case !
	action activate_act {
		list<bouton> selected_but <- bouton overlapping (circle(1) at_location #user_location);
		ask selected_but {action_type<-action_nb;
			bord_col<-#yellow;
			ask bouton {if bouton!=myself {bord_col<-#black;}}
		}
	
		// fail if no budget
		if actions_costs[action_type] > budget {
			write("FAIL: this action costs "+actions_costs[action_type]+" but you only have "+budget+" budget left");
		}
		else {
			bool done_action <- false;
		
			// giant SWITCH action_type TODO une fois les actions codées
			switch action_type {
				match 0 {write("In this columns are actions to modify prices or use monetary incentives. \n Your budget = "+budget);}
				match 1 {write("In this column are actions to build new infrastructures or modify existing ones");}
				match 2 {write("In this column you find actions that change laws and regulations in your town");}
			
				// PRICES
				match 3 {
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
				match 6 {
					// FIXME taxer l'essence et pas les individus? to increase cost of cars
					write("PRICES - Change tax rate");
					write ("Previous tax rate : "+(tax_rate)+"%");
					// read user input for new tax rate		
					map input_values <- user_input(["Tax rate (in %)"::(tax_rate)]);
					// update president with new tax rate from user input
					tax_rate <- float(input_values["Tax rate (in %)"]);
					// user feedback in console
					write ("New tax rate "+(tax_rate)+"%.");
				}
				match 9 {
					write("PRICES - Bus ticket price");
					// read user input for new bus ticket price
					string msg <- "Bus ticket price";
					map input_values <- user_input([msg::(bus_price)]);
					// update president with new tax rate from user input
					bus_price <- float(input_values[msg]);
					// user feedback in console
					write ("New bus price "+(bus_price)+"");
				}
				match 12 {
					write("PRICES - Forbid old cars");
					// to check how accessibility of town evolves
					ask 300 among (people where (each.has_car)) {
						has_car <- false; // cannot use the car anymore
					}
				}
				match 15 {write("PRICES - Action 15");}
				match 18 {write("PRICES - Action 18");}			
				
				// INFRASTRUCTURES
				match 4 {
					write("BUILD - Build cycling lane");
					// cancel budget decrease (will be done per each cell clicked)
					//budget <- budget + actions_costs[action_type];
					// budget will just not be deduced since nothing was done
				}
				match 7 {
					write("BUILD - Plant trees");
					// cancel budget decrease (will be done per each cell clicked)
					//budget <- budget + actions_costs[action_type];
				}
				match 10 {
					write("BUILD - Repair worst road");
					if not empty (road where (each.status < 1.0)) {done_action <- true;}
					else {write("No road needs repairing");}
					ask (road with_min_of each.status) {
						do repair;
						write ("Road "+self+" status "+(self.status with_precision 1));
					}	
				}
				match 13 {
					write("BUILD - Repair all roads");
					list<road> damaged_roads <- road where (each.status < 1.0);
					int cost <- actions_costs[10]*length(damaged_roads);
					if cost < budget {
						actions_costs[13] <- cost;
						//budget <- budget - cost;
						done_action <- true;
						ask damaged_roads { do repair; }
						write("Successfully repaired all "+length(damaged_roads)+" damaged roads");
					}
					else {
						// fail action
						write("This action costs "+cost+" but you only have "+budget+" budget left");
						// repair as many roads as possible (worst case will repair 0, and deduce 0 from budget)
						int n <- int(budget / actions_costs[10]);
						actions_costs[13] <- n*actions_costs[10];
						done_action <- true;
						ask n among damaged_roads {do repair; }
						write("Could only repair "+n+" among "+length(damaged_roads)+" damaged roads");	
					}
					
				}
				match 16 {write("BUILD - Action 16");}
				match 19 {write("BUILD - Action 19");}
			
				// REGULATIONS
				match 5 {
					write("CODE - Improve safety");
					//values_modes[SAFE][WALK] <- min([1,values_modes[SAFE][WALK] * 1.1]) with_precision 2;
					//values_modes[SAFE][BUS] <- min([1,values_modes[SAFE][BUS] * 1.1]) with_precision 2;
					//budget <- budget - 7;
					if town_safety < 1.0 {
						town_safety <- town_safety + 0.1 with_precision 2;
						done_action <- true;
					}
					else {
						write("Safety is already maximal in your town");
					}
				}
				match 8 {
					// build car park: TODO
					write("CODE - Build carparks (Action 8 : TODO)");
				} 
				match 11 {
					write("CODE - Bus frequency");
					if (bus_frequency < 1) {
						// action is feasible
						done_action <- true;
						
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
					}
					else {
						write("Bus frequency already maximal");
					}
				}
				match 14 {
					// FIXME can we reduce bus capacity? any change costs money anyway to reorganize buses
					write("CODE - Bus capacity");
					// read user input for new bus capa
					string msg <- "Bus capacity (in people)";
					int old_capa <- bus_capacity;	
					map input_values <- user_input([msg::(bus_capacity)]);
					bus_capacity <- int(input_values[msg]);
					// if actually changed something
					if old_capa != bus_capacity {
						done_action <- true;
						actions_costs[14] <- 6;
						// user feedback in console
						write("New bus capacity : "+bus_capacity) color: #blue;
					}
				}
				match 17 {
					write("CODE - Add bus stop");
					// TODO : augmenter directement le percent_close_bus (ou bien le nommer bus_cover)
					// TODO: pour l'instant cette variable nb_bus_stops n'a aucun impact nulle part...
					nb_bus_stops <- nb_bus_stops + 1; // will increase density hence practicity, time
										
					// some agents now gain a closer bus stop (about the population of one cell)
					// attention il y a moins de people que de cells... (1000 contre 2500)
					ask 10 among (people where ( not each.has_close_bus)) {
						has_close_bus <- true;
					}
					// always feasible
					actions_costs[17] <- 20;
					done_action <- true;
				}
				match 20 {write("CODE - Action 20");}		
			}
			
			// deduce budget if and only if action was performed indeed
			if (done_action) {
				budget <- budget - actions_costs[action_type];
				write("*** Budget = "+budget);
			}		
		}//end if budget sufficient
	}//end activate_act
		
	
	// actions that need to select a particular cell on the grid
	// called by mouse_down event on map display
	action action_cell {
		list<cell> selected_cell <- cell overlapping (circle(1) at_location #user_location);
		ask one_of (selected_cell) {
			// fail if no budget
			if actions_costs[action_type] > budget {
				write("FAIL: this action costs "+actions_costs[action_type]+" but you only have "+budget+" budget left");
			}
			else {
				bool done_or_not <- false;
				switch action_type {
					match 4 {
						// check feasibility
						list<road> non_cyclable_roads <- (road overlapping self where (each.cycle_lane = false));
						if (not empty(non_cyclable_roads)) {
							do build_cycle_lane;
							done_or_not <- true;						
						}
					}
					match 7 {
						// always feasible to plant trees
						done_or_not <- true;
						do plant_tree;
					}
					default {write("action number "+action_type + " on cell "+self);}
				}
				if done_or_not {budget <- budget - actions_costs[action_type];}
			}	
		}
	}//end action_cell	
	
	// collect taxes
	action collect_budget {
		budget <- budget + tax_rate * length(people);
		write("Tax collected! New budget "+budget);
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
	
	// TODO ONGOING
	// afficher la note moyenne sur la population de chaque mode de transport
	
	
	// *************************
	// ***  GAME MANAGEMENT  ***	
	// *************************
			
	// normal turn
	reflex newTurn when: cycle < 100 {
		write("-------\n Year "+cycle);
			
		// update indicators, and resulting values of the criteria for each mode
		do update_indicators;
		do update_values_modes;   // based on indicators

		// reset count of accident at the start of the year
		ask road {accident_count <- 0;}

		// collect budget from taxes - TODO every year
		do collect_budget;
			
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
	
	// Speed of the agent
	float speed <- 5 #km/#h;
	rgb color <- rnd_color(255);
	
	int mobility_mode; // among: [BICYCLE, CAR, BUS, WALK];
	float happiness <- 0.77;
	bool happy; 
	
	// critères de décision (priorités)
	// 6 critères SAGEO: prix, temps, confort, sécurité, simplicité, écologie
	// only priority differs inter agents (comfort of the bike is the same for all but not as important for all)
	map<int,float> prio_criteria;
	map<int,float> notes_modes;
	
	// store history of happiness to allow comparison along the mandate of the mayor
	// stores : happiness (note du mode choisi) et happy (false: 0, true: 1), chaque année
	// might need: used mode (did it change over the mandate)
	map<int,list<float>> history_happiness;
	list<int> history_mobility <- [];
	
	// habits = how often does the agent use each mode (FIXME: should depend on context?)
	map<int,int> trips_mode; 		// nb of trips per mode over time
	map<int,float> habits_modes;  	// increases when mode is used, reset sometimes
	
	// accidents in the past (TODO impact perception of safety? well-being?) not used yet
	int accidents <- 0; // TODO store different counters for each mode (eg 0 accidents in car, 2 accidents on bike)
	
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
		loop i over: transport_modes {trips_mode[i] <- 0;}
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
		
		// l'historique stocke 200 déplacements au travail par an
		loop i from: 0 to: 200 {
			if (target = nil) {   // and (flip(leaving_proba))  --> always leave !
				// choose random target
				// must leave first to set target, then choose mode might depend on target
				target <- any_location_in(one_of(building));
				do choose_mode;		// 0 if no feasible mode ; also updates happiness
				if (mobility_mode = 0) {target <- nil;}  // give up
				
				// store in history for this year + TODO: also store score of this mode at that time
				add mobility_mode to: history_mobility;
			}
		}
		
		// pour simplifier, on n'anime qu'un déplacement pour l'année
		// only moves if has a target and a mobility mode
		if target != nil {
			do move_to_target; // FIXME might not reach destination this year....
		}
		
		put [happiness, happy?1.0:0.0] at: cycle in: history_happiness;
	}	
	
	
	// ONGOING PROBLEM 1 JULY no one can move at all...
	// all have mobility_mode = 0
	// due to new constraint can_walk in can_use function
	
	// return rationnally preferred mode (independent from constraints)
	int preferred_mode {
		int index_pref <- 1;
		loop i from: 2 to: 4 {
			if notes_modes[i] >= notes_modes[index_pref] {
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
		
	
	// recursive action move to the destination
	action move_to_target {
		do move;
		if target != nil {do move_to_target;}
	}
	
	// Action to move to the target building moving on the road network
	action move {
		//we use the return_path facet to return the path followed
		path path_followed <- goto (target: target, on: road_network, recompute_path: false, return_path: true, move_weights: road_weights);
		
		//if the path followed is not nil (i.e. the agent moved this step), we use it to increase the pollution level of overlapping cell
		if (path_followed != nil ) {
			// pollution along the path taken by the agent
			ask (cell overlapping path_followed.shape) {
				// pollution depends on mobility mode (only car and bus generate pollution, at different levels)
				pollution <- pollution + pollution_modes[myself.mobility_mode];  // + 10
			}
			
			// update counter of yearly km for each road travelled
			year_km_travelled[mobility_mode] <- year_km_travelled[mobility_mode] + length(road overlapping path_followed.shape);
		
			// risk of accident on each cell, the more agents the more risks
			ask (road overlapping path_followed.shape) {
				// bad luck: accident
				if flip(self.accident_risk) {
					accident_count <- accident_count + 1;
					// which agents (driving a car) - TODO handle accidents with bikes if no cycling lane
					list<people> accidented <- 2 among (people at_distance 1 where (each.mobility_mode = CAR));
					ask accidented {accidents <- accidents +1;}
				}
			}
		}
		
		// arrived
		if (location = target) {
			target <- nil;
			// reset mode - cannot move (0) or does not want to move (-1)
			//mobility_mode <- 0; // not moving
		}	
	}
	
	
	
	
	// ************************************************
	// ***       ELECTIONS - CHOOSE CANDIDATE       ***
	// ************************************************
	
	// measure political satisfaction after one mandate
	// ONGOING 2 JULY
	reflex political_satisfaction when: cycle = 6 {
		write("history = "+history_happiness);
		float old_satisf <- history_happiness at 1 at 0;
		float now_satisf <- history_happiness at 6 at 0;
		bool old_happy <- history_happiness at 1 at 0 = 1.0;
		bool now_happy <- history_happiness at 6 at 0 = 1.0; 
		
		write("now happy? "+now_happy+" and before? "+old_happy);
		
		if now_satisf > old_satisf {
			write ("improved satisfaction") color: #green;
		}
		else if now_satisf = old_satisf {
			write("equal satisfaction") color: #blue;
		}
		else {
			write("decreased satisfaction") color: #red;
		}
	}
	
	// TODO ongoing election mechanism
	string vote(list<string> candidates) {
		// doit avoir accès aux priorités des candidats
		// FIXME exprimées sur les critères, ou sur les modes?
		
		return "mon candidat préféré";
	}
	
	
	// ***************************************************
	// ***       VISUALISATION OF CITIZENS ON MAP      ***
	// ***************************************************
	
	// TODO draw with a gif shape + color depending on selected mobility mode
	// TODO another aspect to show happiness with a color
	aspect default {
		draw circle(5) color: color;
	}
}//end species people


//Species to represent the buildings - not scheduled
species building schedules: [] {
	aspect default {
		draw shape color: #gray;
	}
}



//Species to represent the roads
species road {
	//Capacity of the road considering its perimeter
	// TODO la capacité baisse si piste cyclable? (prend de la place)
	float capacity <- 1 + shape.perimeter/30;
	//Number of people on the road
	int nb_people <- 0 update: length(people at_distance 1); 
	// TODO : compter les bus comme une seule personne ! il faut compter les véhicules et pas les people
	
	//Speed coefficient computed using the number of people on the road and the capacity of the road
	// TODO ne pas compter les people à vélo dans la congestion / ne les compter que si en voiture
	float speed_coeff <- 1.0 update:  exp(-nb_people/capacity) min: 0.1;
	int buffer<-3;
	
	// new attributes
	bool cycle_lane <- false;
	// status of maintainment
	float status <- 1.0 min: 0.01;
	// risk of accident on this road
	float accident_risk min: 0.0 max: 1.0;
	int accident_count <- 0;
	
	// degrade over time (speed as a parameter)
	reflex degrade when: flip(roads_degrade_speed) {
		status <- status * 0.9;
	}
	
	// update risk of accident on each road based on traffic and state of surface
	reflex update_risk {
		accident_risk <- accident_proba * 1/self.status * self.nb_people/self.capacity;
	}
	
	// repair this road (add, not multiply, to allow reaching full repair)
	// full repair in one action, and with same fix cost (FIXME cost depends on state?)
	action repair {
		status <- 1.0; 
	}
	
	// draw road with color depending on special lanes (TODO add colors for other lanes: bus, carpooling, etc)
	aspect default {
		draw (shape + buffer * speed_coeff) color: cycle_lane?#green:#red;
	} 
}



//cell use to compute the pollution in the environment
grid cell height: 50 width: 50 neighbors: 8 {
	//pollution level
	float pollution <- 0.0 min: 0.0 max: 100.0;
	
	//color updated according to the pollution level (from red - very polluted to green - no pollution)
	rgb color <- #green update: rgb(255 *(pollution/30.0) , 255 * (1 - (pollution/30.0)), 0.0);
	
	int trees_on_cell <- 0;

	// actions to update town
	action build_cycle_lane {
		ask road overlapping self {
			if !self.cycle_lane {
				self.cycle_lane <- true;
				write("Road "+self+" now equipped with cycling lane");
			}
		}
	}
	
	// TODO chaque arbre absorbe un peu de la pollution chaque jour
	action plant_tree {
		trees_on_cell <- trees_on_cell + 1;
	}
}



/* ******************************************************************
 *******    BOUTONS                                   ***
*********************************************************************/
grid bouton width:3 height:7 
{
	int action_nb;
	float img_h <-world.shape.height/8;
	float img_l <-world.shape.width/4;
	rgb bord_col<-#black;

	aspect normal {
		draw images[action_nb] size:{img_l,img_h} ;
	}
}



experiment play type: gui {
	float minimum_cycle_duration <- 0.01;
 	
	// parameters of the simulator
	//parameter "Moving proba" init: 0.5 min: 0.0 max: 1.0 var: move_proba category: "Parameters";
	
	// Environment
	parameter "Road degrading" init: 0.1 min: 0.0 max: 1.0 var: roads_degrade_speed category: "Environment";
	parameter "Accident proba" init: 0.1 min: 0.0 max: 1.0 var: accident_proba category: "Environment";
	parameter "Weather comfort" init: 0.5 min: 0.0 max: 1.0 var: weather category: "Environment";
	
	// Population
	parameter "Habit drop proba 0-1" init: 0.05 min: 0.0 max: 1.0 var: habit_drop_proba category: "Population";
	parameter "Average population fitness" init: 0.5 min: 0.0 max: 1.0 var: avg_fitness category: "Population";
	parameter "Who has a bike (%)" init: 0.7 min: 0.0 max: 1.0 var: percent_has_bike category: "Population";
	parameter "Who has a car (%)" init: 0.9 min: 0.0 max: 1.0 var: percent_has_car category: "Population";
	parameter "Who has a bus stop (%)" init: 0.5 min: 0.0 max: 1.0 var: percent_close_bus category: "Population";
	parameter "Who can walk (%)" init: 0.2 min: 0.0 max: 1.0 var: percent_can_walk category: "Population";
	// TODO population size?
	
	output {
 		layout horizontal([vertical([0::5676,1::4324])::3107,vertical([horizontal([2::5000,3::5000])::3859,4::6141])::6893]) tabs:true editors: false;

		display carte type: opengl {
			event mouse_down action:action_cell;  // what happens when clicking on a cell of the grid
			
			species building refresh: false;
			species road ;
			species people ;
			
			//display the pollution grid in 3D using triangulation.
			grid cell elevation: pollution * 3.0 triangulation: true transparency: 0.7; // lines: #black;
		
		}//end display carte
		
		// written indicators
		display indicateurs name:"Indicateurs" ambient_light:100 {	
    		graphics position:{ 2, 2 } size:{ 200 #px, 180 #px } { // overlay background:#white rounded:true   transparency:1     {
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
				draw " - % of cycling lanes on roads "+100*indic_cyclability + " %" at: {d, 100#px} color: #black;
				draw " - Number of trees " + indic_trees at: {d, 120#px} color: #black;
				draw " - "+ world.nb_trips_year() + " trips over "+ world.nb_km_year()+" km" at: {d, 140#px} color: #black;
				draw " - "+nb_roads_damaged+" roads damaged ("+avg_damage+"% damage avg)" at: {d, 160#px} color: #red;
				draw " - Accident rate : "+accident_rate with_precision 2 at:{d,180#px} color: #red;
				draw " - Town safety : "+town_safety at: {d,200#px} color: #blue;
				draw " - Bus density : "+percent_close_bus*100+" %" at: {d, 220#px} color: #blue;
				draw " - Pop happiness : "+indic_happiness at: {d, 240#px} color: #green;				
				draw " - Pop happy % : "+indic_happy at: {d, 260#px} color: #green;
				draw " - Accessibility % : "+(indic_accessibility*100)+" %" at: {d, 280#px} color: #pink;
       		}//end overlay
		}//end display indicators
		
		//Boutons d'action
		display action_button name:"Actions possibles" ambient_light:100 	{
			grid bouton triangulation:false;
			species bouton aspect:normal ;
			event mouse_down action:activate_act;    
		}		
		
		display KmPerMode {
			chart "Current year km/mode"  size: {0.5,0.5} position: {0, 0} type:pie
			{
				data "bicycle km" value:year_km_travelled[BICYCLE] color:°green; // / world.nb_km_year()
				data "car km" value:year_km_travelled[CAR] color:°red;
				data "bus km" value:year_km_travelled[BUS] color:°blue;
				data "walk km" value:year_km_travelled[WALK] color:°yellow;
			}
			
			chart "Total km/mode"  size: {0.5,0.5} position: {0.5, 0} type:pie axes:#white
			{
				data "bicycle km" value:total_km_travelled[BICYCLE] accumulate_values:true color:°green; // / world.nb_km_total()
				data "car km" value:total_km_travelled[CAR] accumulate_values:true color:°red;
				data "bus km" value:total_km_travelled[BUS] accumulate_values:true color:°blue;
				data "walk km" value:total_km_travelled[WALK] accumulate_values:true color:°yellow;				
			}
			
			chart "Km/mode over time"   size: {1.0,0.5} position: {0, 0.5} type:series 
			series_label_position: legend
			{
				data "bicycle km" value:year_km_travelled[BICYCLE] color:°green;   // / world.nb_km_year()
				data "car km" value:year_km_travelled[CAR] color:°red;
				data "bus km" value:year_km_travelled[BUS]  color:°blue;
				data "walk km" value:year_km_travelled[WALK] color:°yellow;			
			}
		}//end display graphiques
		

		display TripsPerMode {
			chart "Current year trips/mode"  size: {0.5,0.5} position: {0, 0} type:pie
			{
				//int paf <- sum(year_trips.values)=0?1:sum(year_trips.values);
				data "bicycle km" value:year_trips[BICYCLE] color:°green;
				data "car km" value:year_trips[CAR] color:°red;
				data "bus km" value:year_trips[BUS] color:°blue;
				data "walk km" value:year_trips[WALK] color:°yellow;
			}
			
			chart "Total trips/mode"  size: {0.5,0.5} position: {0.5, 0} type:pie
			axes:#white

			{
				//int t <- sum(total_trips.values)=0?1:sum(total_trips.values);
				data "bicycle trips" value:total_trips[BICYCLE] accumulate_values:true color:°green;
				data "car trips" value:total_trips[CAR] accumulate_values:true color:°red;
				data "bus trips" value:total_trips[BUS] accumulate_values:true color:°blue;
				data "walk trips" value:total_trips[WALK] accumulate_values:true color:°yellow;				
			}
			
			chart "Trips/mode over time"   size: {1.0,0.5} position: {0, 0.5} type:series 
			series_label_position: legend style: line
			//style:stack
			{
				//int pif <- sum(year_trips.values)=0?1:sum(year_trips.values);
				//write t color: #orange;
				data "bicycle km" value:year_trips[BICYCLE] color:°green ; //  accumulate_values:true 
				data "car km" value:year_trips[CAR] color:°red;
				data "bus km" value:year_trips[BUS] color:°blue;
				data "walk km" value:year_trips[WALK] color:°yellow;	
				
				//datalist ["empty","carry"] accumulate_values:true 
				//value:[(list(ant) count (!each.hasFood)),(list(ant) count (each.hasFood))] 
				//color:[°red,°green];				
			}
		}//end display graphiques
		
		
	}//end output
}//end expe
