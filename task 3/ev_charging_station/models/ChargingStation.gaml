/**
* Name: ChargingStation
* Author: Zack Aemmer
*/
// Default units are meters and seconds
// Default space is 100x100 grid

model ChargingStation

// TODO:
// Specify logic for choosing plug when not homogeneous powers
// Draw vehicle characteristics based on data
// Draw arrival rate based on AADT/ToD/Chargeval
// Implement plugin delay

global {
	// Input parameter defaults
	float STATION_SPACING <- 50.0;
	float RANGE_ANXIETY_BUFFER <- 10.0;
	int CHARGE_PLUGIN_DELAY <- 30;
	list<float> PLUG_POWERS <- [150.0, 150.0, 150.0, 150.0];
	list<float> VEHICLE_CAPACITIES <- [50.0, 100.0, 150.0, 200.0];
	
	float ARRIVAL_RATE <- 2 / 3600;

	// Global variables modified during the simulation
	int current_hour <- 0;

	// Graphics constants
	int SPACING <- 5;
	point CHARGER_LOC <- {50,50};
	point QUEUE_LOC <- CHARGER_LOC - {5,0};

	// Initialize plugs and charger
	init {
		create charger number: 1 with:(
			location: CHARGER_LOC,
			name: "main_charger"
		);
	}
	// Keep track of the hour of the day
	reflex update {
		float hours_of_sim <- (time / 3600);
		float days_of_sim <- (hours_of_sim / 24);
		current_hour <- mod(hours_of_sim, 24);
	}
	// Create new vehicles according to long distance AADT and Time of Day
    reflex vehicleArrival when: (flip(ARRIVAL_RATE)) {
    	point new_vehicle_loc <- QUEUE_LOC - {SPACING, 0};
    	create vehicle number: 1 with: (
    		location: new_vehicle_loc,
    		in_queue: false,
    		capacity: one_of(VEHICLE_CAPACITIES)
    	);
    }
}


species charger {
	list<vehicle> queue;
	list<bool> plug_availability;
	
	init {
		loop i from: 0 to: length(PLUG_POWERS)-1 {
			plug_availability <- plug_availability + true;
		}
	}
	// Pull all newly arrived vehicles into queue
	reflex update_queue {
		ask vehicle.population {
			if (self.in_queue = false) {
				myself.queue <- myself.queue + self;
				self.in_queue <- true;
			}
		}
	}
	// Assign vehicles from queue to plugs
	reflex serve_queue {
		loop i over: queue {
			// For now just serve with open plugs
			loop j from: 0 to: length(plug_availability)-1 {
				if (plug_availability[j]) {
					queue <- queue - i;
					i.incoming_charge_power <- PLUG_POWERS[j];
					i.plug_num <- j;
					plug_availability[j] <- false;
					break;
				}
			}
		}
	}
	aspect base {
		draw rectangle(5,3) color: #blue border: #black;
	}
}

species vehicle {
	float soc;
	float capacity;
	float acceptance_curve;
	float energy_intensity;
	float max_charge_power;
	bool in_queue;
	int plug_num;
	float incoming_charge_power <- 0.0;
    rgb color <- rnd_color(255);
	
	// Initialize vehicle SOC based on simulation parameters
	init {
		float remaining_miles <- STATION_SPACING + RANGE_ANXIETY_BUFFER;
		float remaining_energy <- remaining_miles * energy_intensity;
		soc <- remaining_energy / capacity;
	}
	// Add charge if connected to power
	reflex charge {
		if (incoming_charge_power > 0.0) {
			// kW-sec coming from charger, as a proportion of capacity which is kW-hour
			soc <- soc + (incoming_charge_power / (capacity * 3600));
		}
	}
	// When SOC over threshold; free up the plug and leave
	reflex depart {
		if (soc > 0.80) {
			ask charger {
				self.plug_availability[myself.plug_num] <- true;
			}
			do die;
		}
	}
	aspect base {
		draw circle(1) color: #red border: #black;
	}
}


experiment simple_station type: gui {
	parameter "Station Spacing (miles):" var: STATION_SPACING;
	parameter "Range Anxiety Buffer (miles):" var: RANGE_ANXIETY_BUFFER;
	parameter "Charge Plugin Delay (seconds):" var: CHARGE_PLUGIN_DELAY;
	parameter "Plugs and Power (kWh):" var: PLUG_POWERS;

	output {
//		Downtime (unutilized charging capacity)
//		Average queue length/wait time
//		Max queue length/wait time
//		Total charging time
//		Total queueing time
//		Total charging time
//		Total queueing time
//		Operation costs ($)
//		Peak power consumption (kW)
//		Average power consumption

		// Main graphical display
		display station_display {
			species charger aspect: base;
			species vehicle aspect: base;
		}
		// Tables for browsing species statuses
		inspect "vehicle_browser" value: vehicle type: table;
		inspect "charger_browser" value: charger type: table;
		// Count of vehicles in simulation
		display station_performance {
			chart "Number of Vehicles in System" type: series {
				data "vehicle count" value: length(vehicle.population);
			}
		}
		// Total plug power being provided
		display power_supplied {
			chart "Power Consumption (kW)" type: series {
				data "power_consumption" value: sum(vehicle collect(each.incoming_charge_power));
			}
		}
		// Visual of vehicles currently being charged
		display charge_status {
			chart "Vehicle SOC (%)" type: series {
                datalist vehicle collect(each.name) value: vehicle collect(each.soc) color: vehicle collect(each.color);
			}
		}
	}
}
