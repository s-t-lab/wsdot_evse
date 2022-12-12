/**
* Name: ChargingStation
* Author: Zack Aemmer
*/
// Default units are meters and seconds
// Default space is 100x100 grid


model ChargingStation


global {
	// Time
	float step <- 1 #mn;

	// Input parameter defaults
	float LD_AADT <- 3500.0;
	float EV_PROPORTION <- 0.0094;
	float STATION_SPACING <- 50.0;
	float RANGE_ANXIETY_BUFFER <- 10.0;
	float DEPARTING_SOC <- 0.80;
	int CHARGE_PLUGIN_DELAY <- 3;
	float TEST_CYCLE_ADJ_FACTOR <- 0.15;
	list<float> PLUG_POWERS <- [150.0, 150.0, 150.0, 150.0];
	list<string> VEHICLE_MODELS <- [
		"2022 Mach-E RWD ER",
		"2022 ID.4 Pro",
		"2022 Bolt",
		"2023 Leaf SV",
		"2022 F-150 Lightning ER",
		"2022 Model S Plaid"
	];
	list<float> VEHICLE_EFFICIENCIES <- [
		(90.0/33.7) with_precision 2,
		(98.0/33.7) with_precision 2,
		(109.0/33.7) with_precision 2,
		(98.0/33.7) with_precision 2,
		(63.0/33.7) with_precision 2,
		(112.0/33.7) with_precision 2
	]; // MPGe (33.7 kWh per gal)
	list<float> VEHICLE_RANGES <- [303.0, 275.0, 259.0, 212.0, 320.0, 396.0];
	list<float> VEHICLE_MAX_DESIRED_CHARGE <- [150.0, 135.0, 55.0, 150.0, 150.0, 250.0];
	list<float> VEHICLE_WEIGHTS <- [1/6, 1/6, 1/6, 1/6, 1/6, 1/6];
	float MAX_C_RATE_SLOPE <- -2.50;
	float MIN_C_RATE_SLOPE <- -0.75;	

	// Global variables modified during the simulation
	list<float> STOPPING_PROPORTIONS;
	int current_min <- 0;
	int current_hour <- 0;
	list<float> vehicle_delays <- [0.0];
	list<float> charging_times <- [0.0];
	// Metric: power draw
	float current_power_draw <- 0.0;
	list<float> rolling_avg_power_draw <- [0.0];
	// Metric: queue delay
	float current_queue_delay <- 0.0;
	list<float> rolling_avg_queue_delay <- [0.0];
	// Metric: arrival rate
	float current_arrival_rate <- 0.0;
	list<float> rolling_avg_arrival_rate <- [0.0];

	// To be loaded from files
	list<float> KFACTOR_TIMES;
	list<float> KFACTORS;
	list<float> ARRIVAL_RATES;

	// Graphics constants
	int SPACING <- 5;
	point CHARGER_LOC <- {50,50};
	point QUEUE_LOC <- CHARGER_LOC - {5,0};

	// Initialize plugs and charger
	init {
		loop i from: 0 to: length(VEHICLE_MODELS) - 1 {
			float range_arrive <- RANGE_ANXIETY_BUFFER + (STATION_SPACING / 2.0); // Arrival rates based on expected value, adjustment is calculated for individual vehicles
			float range_depart <- VEHICLE_RANGES[i] * DEPARTING_SOC;
			STOPPING_PROPORTIONS <- STOPPING_PROPORTIONS + (STATION_SPACING / (range_depart - range_arrive));
		}
		create charger number: 1 with:(
			location: CHARGER_LOC,
			name: "main_charger"
		);
		// Read in data files and construct arrival rate curves
		file k_factors_file <- csv_file("../data/avg_kfactor.csv");
		loop i from: 0 to: k_factors_file.contents.rows - 1 {
			KFACTOR_TIMES <- KFACTOR_TIMES + float(k_factors_file.contents[1,i]);
			KFACTORS <- KFACTORS + float(k_factors_file.contents[2,i]);
			ARRIVAL_RATES <- ARRIVAL_RATES + (LD_AADT * EV_PROPORTION * float(k_factors_file.contents[2,i]) / 5);
		}
	}
	// Run every simulation step
	reflex update_metrics {
		// Simulation times
		float mins_of_sim <- (time / 60);
		float hours_of_sim <- (time / 3600);
		float days_of_sim <- (hours_of_sim / 24);
		current_min <- mod(mins_of_sim, 24 * 60);
		current_hour <- mod(hours_of_sim, 24);
		// Power draw
		current_power_draw <- sum(vehicle collect(each.limited_charge_power));
		rolling_avg_power_draw <- rolling_avg_power_draw + current_power_draw;
		// Queue delay
		rolling_avg_queue_delay <- rolling_avg_queue_delay + current_queue_delay;
		// Arrival rate
		current_arrival_rate <- ARRIVAL_RATES at int(current_min / 5);
		rolling_avg_arrival_rate <- rolling_avg_arrival_rate + current_arrival_rate;
	}
	// Create new vehicles according to long distance AADT and Time of Day
    reflex vehicle_arrival {
    	loop i from: 0 to: length(VEHICLE_MODELS) - 1 {
    		if (flip(current_arrival_rate * STOPPING_PROPORTIONS[i] * VEHICLE_WEIGHTS[i])) {
		    	create vehicle number: 1 with: (
		    		in_queue: false,
		    		spot_in_queue: length(vehicle.population),
		    		design_model: VEHICLE_MODELS at i,
		    		efficiency: (VEHICLE_EFFICIENCIES at i) * (1.0 - TEST_CYCLE_ADJ_FACTOR),
		    		range: VEHICLE_RANGES at i,
		    		max_charge_rate: VEHICLE_MAX_DESIRED_CHARGE at i,
		    		c_rate_slope: rnd(MIN_C_RATE_SLOPE, MAX_C_RATE_SLOPE)
	    		);
    		}
    	}

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
			}
		}
	}
	// Assign vehicles from queue to plugs
	reflex serve_queue {
		loop i over: queue {
			// Returns -1 if no plugs available, otherwise give vehicle their chosen plug
			ask i {
				int chosen_plug <- choose_plug(myself.plug_availability, PLUG_POWERS);
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
	float efficiency;
	float range;
	float capacity;
	float c_rate_slope;
	float c_rate_intercept;
	// Current charging status
	float soc;
	float max_charge_rate;
	float incoming_charge_power <- 0.0;
	float limited_charge_power <- 0.0;
	bool in_queue;
	int spot_in_queue;
	int plug_num <- -1;
	// Performance metrics
	float time_in_system <- 0.0;
	float time_charging <- 0.0;
	// Graphics
    rgb color <- rnd_color(255);

	// Initialize vehicle SOC based on simulation parameters
	init {
		// Initialize y-intercept such that c-rate goes to 0.00 at 100% soc
		c_rate_intercept <- -c_rate_slope;
		// Battery capacity kWh based on efficiency and range
		capacity <- (1 / efficiency) * range; // mi * (kW/mi) = kW
		// Random uniform draw for remaining energy, assume station is passed if enough range to do so
		float remaining_distance <- rnd(RANGE_ANXIETY_BUFFER, STATION_SPACING + RANGE_ANXIETY_BUFFER);
		// Energy to travel that remaining distance depends on the vehicle
		float remaining_energy <- remaining_distance * (1 / efficiency); // mi * kWh/mi = kWh
		// State of charge % of total battery capacity
		soc <- remaining_energy / capacity; // % = kWh / kWh
	}
	// Run every timestep
	reflex update {
		location <- QUEUE_LOC - {SPACING * spot_in_queue, 0};
		// There is a 1-step period where the vehicle is not yet in queue; do not count towards delay
		if (in_queue = true) {
			time_in_system <- time_in_system + 1;
		}
		// Any time where charge is supplied counts toward charging delay, not queue
		if (incoming_charge_power > 0.0) {
			time_charging <- time_charging + 1;
		}
	}
	// Add charge if connected to power
	reflex charge {
		if (incoming_charge_power > 0.0) {
			// Get max possible charge rate given the vehicle acceptance curve and current SOC
			float c_rate <- c_rate_intercept + (c_rate_slope * soc);
			float desired_charge_power <- c_rate * capacity;
			// Can't pull more power than is available from current plug
			limited_charge_power <- min(desired_charge_power, incoming_charge_power);
			// %-min coming from charger, as a proportion of capacity which is kWh
			soc <- soc + (limited_charge_power / (capacity * 60));
		}
	}
	// When SOC over threshold; free up the plug and leave
	reflex depart {
		if (soc > DEPARTING_SOC) {
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
			// Update the most recent measure of queue delay
			current_queue_delay <- self.time_in_system - self.time_charging;
			// Leave simulation after done charging
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
		loop i from: 0 to: length(plug_availabilities) - 1 {
			if (best_plug_power >= self.max_charge_rate) {
				desired_power_met <- true;
			}
			if (desired_power_met) {
				// Minimum above threshold (should never have to go back through list since bool is flagged first time charger meets max)
				if (plug_availabilities[i] and (plug_powers[i] < best_plug_power) and (plug_powers[i] >= self.max_charge_rate)) {
					best_plug <- i;
					best_plug_power <- plug_powers[i];
				}
			} else if (plug_availabilities[i] and (plug_powers[i] > best_plug_power)) {
				// Maximum available
				best_plug <- i;
				best_plug_power <- plug_powers[i];
			}
		}
		return best_plug;
	}
	aspect base {
		draw circle(1) color: color border: #black;
	}
}


// Batch run multiple 1-day simulations
experiment "Batch Simulation" type: batch repeat: 10 keep_seed: false until: (cycle > 60 * 24) {
    reflex end_of_runs {
	    int cpt <- 0;
	    ask simulations {
	    	loop i over: self.rolling_avg_arrival_rate {
	    		save i to: "./batch_results/ar_sim_" + cpt + ".csv" type: text rewrite: false;
	    	}
	    	loop i over: self.rolling_avg_power_draw {
	    		save i to: "./batch_results/pd_sim_" + cpt + ".csv" type: text rewrite: false;
	    	}
	    	loop i over: self.rolling_avg_queue_delay {
	    		save i to: "./batch_results/qd_sim_" + cpt + ".csv" type: text rewrite: false;
	    	}
	        cpt <- cpt + 1;
	    }
    }
}

// Single simulation with plots
experiment "Graphical Simulation" type: gui {
	parameter "AADT (veh/day):" var: LD_AADT;
	parameter "EV Proportion of Fleet (%):" var: EV_PROPORTION;
	parameter "Station Spacing (miles):" var: STATION_SPACING;
	parameter "Range Anxiety Buffer (miles):" var: RANGE_ANXIETY_BUFFER;
	parameter "Charge Plugin Delay (minutes):" var: CHARGE_PLUGIN_DELAY;
	parameter "Test Cycle Adjustment Factor (%)" var: TEST_CYCLE_ADJ_FACTOR;
	parameter "Plugs and Power (kWh):" var: PLUG_POWERS;
	parameter "% SOC to Leave Station:" var: DEPARTING_SOC;
	parameter "Vehicle Models:" var: VEHICLE_MODELS;
	parameter "Vehicle Efficiencies (mi/kWh):" var: VEHICLE_EFFICIENCIES;
	parameter "Vehicle Ranges (mi):" var: VEHICLE_RANGES;
	parameter "Vehicle Max Desired Power (kW):" var: VEHICLE_MAX_DESIRED_CHARGE;

	output {
		// Rolling average of total plug power being provided
		display "power_supplied" {
			chart "Power Consumption (kW)" type: series x_label: 'mins of sim' {
				data "Power Consumption" value: current_power_draw;
			}
		}
		// Rolling average of queueing delay
		display "queueing_delay" {
			chart "Queue Delay (veh-min)" type: series x_label: 'mins of sim' {
				data "Queue Delay" value: current_queue_delay;
			}
		}
		// Count of vehicles in simulation
		display "queue_length" {
			chart "Vehicles in System" type: series x_label: 'mins of sim' {
				data "Vehicle Count" value: length(vehicle.population) color: #blue;
				data "Queue Length" value: max(0, length(vehicle.population) - length(PLUG_POWERS)) color: #red;
			}
		}
		// Number of vehicles currently being charged
		display "charge_status" {
			chart "Vehicle SOC (%)" type: series x_label: 'mins of sim' y_range: [0.0, 1.0] {
                datalist vehicle collect(each.name) value: vehicle collect(each.soc) color: vehicle collect(each.color);
			}
		}
		// Main graphical display
		display "station_display" {
			species charger aspect: base;
			species vehicle aspect: base;
		}
		// Tables for browsing species statuses
		inspect "vehicle_browser" value: vehicle type: table;
		inspect "charger_browser" value: charger type: table;
	}
}
