/**
* Name: ChargingStation
* Author: Zack Aemmer
*/
// Default units are meters and seconds
// Default space is 100x100 grid

model ChargingStation

// TODO:
// Draw arrival rate based on AADT/ToD/Chargeval
// Implement plugin delay
// Multiplexing


global {
	// Input parameter defaults
	float EV_PROPORTION <- 0.10;
	float STATION_SPACING <- 50.0;
	float RANGE_ANXIETY_BUFFER <- 10.0;
	int CHARGE_PLUGIN_DELAY <- 30;
	list<float> PLUG_POWERS <- [350.0, 150.0, 50.0, 50.0];

	// Fixed parameters
	list<string> VEHICLE_MODELS <- ["Mach-E", "ID.4", "Bolt", "Leaf Plus", "F-150 ER", "Model-S Plaid"];
	list<float> VEHICLE_CAPACITIES <- [99.0, 82.0, 65.0, 62.0, 145.0, 100.0];
	list<float> VEHICLE_RANGES <- [249.2, 230.0, 233.4, 192.5, 320.0, 341.0];
	float C_RATE_INTERCEPT_COEF <- 1.49;
	float C_RATE_INTERCEPT_SD <- 0.045;
	float C_RATE_SOC_COEF <- -1.21;
	float C_RATE_SOC_SD <- 0.076;
	// Need veh/sec:
	// LD-AADT from Chargeval
	// Look at 
	float ARRIVAL_RATE <- 5 / 3600; //Placeholder

	// Global variables modified during the simulation
	int current_hour <- 0;
	list<float> vehicle_delays <- [0.0];
	list<float> charging_times <- [0.0];
	float peak_delay <- 0.0;
	float peak_power_draw <- 0.0;
	float avg_power_draw <- 0.0;
	list<float> rolling_avg_power_draw <- [0.0];

	// Graphics constants
	int SPACING <- 5;
	point CHARGER_LOC <- {50,50};
	point QUEUE_LOC <- CHARGER_LOC - {5,0};
	int ROLLING_WINDOW <- 60 * 10;

	// Initialize plugs and charger
	init {
		create charger number: 1 with:(
			location: CHARGER_LOC,
			name: "main_charger"
		);
	}
	// Run every simulation step
	reflex update {
		// Simulation time
		float hours_of_sim <- (time / 3600);
		float days_of_sim <- (hours_of_sim / 24);
		current_hour <- mod(hours_of_sim, 24);
		// Power draw
		float current_power_draw <- sum(vehicle collect(each.limited_charge_power));
		avg_power_draw <- (avg_power_draw + current_power_draw) / 2.0;
		if (current_power_draw > peak_power_draw) {
			peak_power_draw <- current_power_draw;
		}
		rolling_avg_power_draw <- rolling_avg_power_draw + current_power_draw;
		if (length(rolling_avg_power_draw) >= ROLLING_WINDOW) {
			remove from: rolling_avg_power_draw index: 0;
		}
	}
	// Create new vehicles according to long distance AADT and Time of Day
    reflex vehicleArrival when: (flip(ARRIVAL_RATE)) {
    	int model_rnd <- rnd(length(VEHICLE_MODELS)-1);
    	write model_rnd;
    	create vehicle number: 1 with: (
    		in_queue: false,
    		design_model: VEHICLE_MODELS at model_rnd,
    		capacity: VEHICLE_CAPACITIES at model_rnd,
    		range: VEHICLE_RANGES at model_rnd,
    		c_rate_slope: gauss({C_RATE_SOC_COEF, C_RATE_SOC_SD}),
    		c_rate_intercept: gauss({C_RATE_INTERCEPT_COEF, C_RATE_INTERCEPT_SD})
    	);
    }
}


species charger {
	list<vehicle> queue;
	list<bool> plug_availability;

	// Initialize plugs to be all available
	init {
		loop i from: 0 to: length(PLUG_POWERS) - 1 {
			plug_availability <- plug_availability + true;
		}
	}
	// Pull all newly arrived vehicles into queue
	reflex update_queue {
		ask vehicle.population {
			if (self.in_queue = false) {
				myself.queue <- myself.queue + self;
				self.in_queue <- true;
				self.spot_in_queue <- length(vehicle.population);
			}
		}
	}
	// Assign vehicles from queue to plugs
	reflex serve_queue {
		loop i over: queue {
			// Returns -1 if no plugs available, otherwise give vehicle their chosen plug
			int chosen_plug;
			ask i {
				chosen_plug <- choose_plug(myself.plug_availability, PLUG_POWERS);
				// Plug in
				if (chosen_plug >= 0 and myself.plug_availability[chosen_plug]) {
					myself.queue <- myself.queue - i;
					self.incoming_charge_power <- PLUG_POWERS[chosen_plug];
					self.plug_num <- chosen_plug;
					myself.plug_availability[chosen_plug] <- false;
				}
			}
		}
	}
	aspect base {
		draw rectangle(5,3) color: #blue border: #black;
	}
}

species vehicle {
	// Vehicle attributes
	string design_model;
	float capacity;
	float range;
	float c_rate_slope;
	float c_rate_intercept;
	// Current charging status
	float soc;
	float max_charge_power;
	float incoming_charge_power <- 0.0;
	float limited_charge_power <- 0.0;
	bool in_queue;
	int spot_in_queue;
	int plug_num;
	// Performance metrics
	float time_in_system <- 0.0;
	float time_charging <- 0.0;
	// Graphics
    rgb color <- rnd_color(255);

	// Initialize vehicle SOC based on simulation parameters
	init {
		float remaining_distance <- STATION_SPACING + RANGE_ANXIETY_BUFFER;
		float remaining_energy <- remaining_distance * (capacity / range); // mi * kWh/mi = kWh
		soc <- remaining_energy / capacity; // % = kWh / kWh
	}
	// Run every timestep
	reflex update {
		location <- QUEUE_LOC - {SPACING * spot_in_queue, 0};
		time_in_system <- time_in_system + 1;
		if (incoming_charge_power > 0.0) {
			time_charging <- time_charging + 1;
		}
	}
	// Add charge if connected to power
	reflex charge {
		if (incoming_charge_power > 0.0) {
			// Get max possible charge rate given the vehicle acceptance curve and current SOC
			float c_rate <- c_rate_intercept + (c_rate_slope * soc);
			float power_draw <- c_rate * capacity;
			// Can't pull more power than is available from current plug
			limited_charge_power <- min(power_draw, incoming_charge_power);
			// %-sec coming from charger, as a proportion of capacity which is kWh
			soc <- soc + (limited_charge_power / (capacity * 3600));
		}
	}
	// When SOC over threshold; free up the plug and leave
	reflex depart {
		if (soc > 0.80) {
			// Free up the plug
			ask charger {
				self.plug_availability[myself.plug_num] <- true;
			}
			// All vehicles behind this one move forward one spot
			ask vehicle {
				if (self.spot_in_queue > myself.spot_in_queue) {
					self.spot_in_queue <- self.spot_in_queue - 1;
				}
			}
			// Update performance metrics
			vehicle_delays <- vehicle_delays + self.time_in_system;
			charging_times <- charging_times + self.time_charging;
			if (self.time_in_system > peak_delay) {
				peak_delay <- self.time_in_system;
			}
			write self.time_charging / 60.0;
			// Leave simulation
			do die;
		}
	}
	// Action to pick the lowest-power available plug that meets max charging rate
	int choose_plug (list<bool> plug_availabilities, list<float> plug_powers) {
		bool desired_power_met <- false;
		int best_plug <- -1;
		float best_plug_power <- 0.0;
		// Cases: 1) No plug available that meets max power; highest. 2) 1+ plugs available that meet max power; lowest above threshold.
		// Keep track of highest until desired power met; then keep track of lowest that meets threshold.
		loop i from: 0 to: length(plug_availabilities)-1 {
			if (desired_power_met) {
				// Minimum above threshold (should never have to go back through list since bool is flagged first time charger meets max)
				if (plug_availabilities[i] and plug_powers[i] < best_plug_power and plug_powers[i] >= self.max_charge_power) {
					best_plug <- i;
					best_plug_power <- plug_powers[i];
				}
			} else {
				// Maximum available
				if (plug_availabilities[i] and plug_powers[i] > best_plug_power) {
					best_plug <- i;
					best_plug_power <- plug_powers[i];
				}
			}
		}
		return best_plug;
	}
	aspect base {
		draw circle(1) color: color border: #black;
	}
}


experiment simple_station type: gui {
	parameter "EV Proportion of Fleet (%):" var: EV_PROPORTION;
	parameter "Station Spacing (miles):" var: STATION_SPACING;
	parameter "Range Anxiety Buffer (miles):" var: RANGE_ANXIETY_BUFFER;
	parameter "Charge Plugin Delay (seconds):" var: CHARGE_PLUGIN_DELAY;
	parameter "Plugs and Power (kWh):" var: PLUG_POWERS;

	output {

		// Count of vehicles in simulation
		display "queue_length" {
			chart "Vehicles in System" type: series {
				data "Vehicle Count" value: length(vehicle.population) color: #blue;
				data "Queue Length" value: max(0, length(vehicle.population) - length(PLUG_POWERS)) color: #red;
			}
		}
		// Rolling average of total plug power being provided
		display "power_supplied" {
			chart "Average Power Consumption (kW)" type: series {
				data "Power Consumption" value: mean(rolling_avg_power_draw);
			}
		}
		// Utilization rate of total station power
		display "power_utilization" {
			chart "Available Power Utilized (%)" type: series y_range: [0.0, 1.0] {
				data "Power Utilization" value: sum(vehicle collect(each.limited_charge_power)) / sum(PLUG_POWERS);
			}
		}
		// Number of vehicles currently being charged
		display "charge_status" {
			chart "Vehicle SOC (%)" type: series y_range: [0.0, 1.0] {
                datalist vehicle collect(each.name) value: vehicle collect(each.soc) color: vehicle collect(each.color);
			}
		}
		// Average delay across all vehicles that departed the system
        display "vehicle_delays" {
	        chart "Distribution of Vehicle Delays" type: histogram {
	        	datalist (distribution_of(vehicle_delays collect(each / 60.0),20,0,120) at "legend") value:(distribution_of(vehicle_delays collect(each / 60.0),20,0,120) at "values");      
        	}
        }
		// Main graphical display
		display "station_display" {
			species charger aspect: base;
			species vehicle aspect: base;
		}
		// Tables for browsing species statuses
//		inspect "vehicle_browser" value: vehicle type: table;
//		inspect "charger_browser" value: charger type: table;
	}
}
