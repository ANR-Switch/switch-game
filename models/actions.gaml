/***
* Name: actions
* Author: kaolla
* Description: 
* Tags: Tag1, Tag2, TagN
***/

model actions

/* Insert your model definition here */

global {
	string dossierImages <-  "../includes/imgs/" ;
	
	int tax_rate <- 5;
	int petrol_price <- 7;
	
	init {
		do create_buttons;
	}

	//draw "INFO" at: #user_location;
//	ask bouton {do inform;}
 	
//	write("click at "+#user_location);
//	write bouton overlapping #user_location;
 
	action create_buttons {
		create bouton {
			action_nb <- CHANGE_PETROL_PRICE;
			col <- 1;
			line <- 1;
			ma_description <- "change petrol price";
			mon_image <- image_file(dossierImages +"petrol-price.jpeg");
		}
		
		create bouton {
			action_nb <- CHANGE_TAX_RATE;
			col <- 1;
			line <- 2;
			ma_description <- "Change tax rate";
			mon_image <- image_file(dossierImages + "taxrate.png");
		}
		
		ask bouton {do post;}
	}
	
}



// ONGOING créer les boutons 1 par 1 avec leur action, leur texte, leur image
species bouton 
{
	int action_nb;
	int col;
	int line;
	float img_h <-world.shape.height/8;
	float img_l <-world.shape.width/5;
	rgb bord_col<-#black;

	string ma_description;
	image_file mon_image;
	
	bool display_info <- false; // update: self overlaps (circle(2) at_location #user_location);
	//point info_location <- location;
	
	// à appeler à la création pour positionner le bouton
	action post {
		location <- {col*img_l,line*img_h};
		shape <- circle(4);
	}
	
	action activate {
		if(self overlaps (circle(2) at_location #user_location)) {
			write(ma_description);
			do dispatch;
		}
	}
	
	action inform {display_info <- self overlaps (circle(2) at_location #user_location);}
	
	int CHANGE_TAX_RATE <- 0;
	int CHANGE_PETROL_PRICE <- 1;
	
	action dispatch {
		switch action_nb {
			match CHANGE_TAX_RATE {do change_tax_rate;}
			match CHANGE_PETROL_PRICE {do change_petrol_price;}	
		}
	}
	
	
	action change_tax_rate {
		write("new tax rate = 222");
		tax_rate <- 222;
	}
	
	action change_petrol_price {
		write("new price of petrol = 333");
		petrol_price <- 333;
	}
	
	
	// affichage
	aspect normal {
		//draw images[action_nb] size:{img_l/2,img_h/2};
		draw mon_image size:{img_l/2,img_h/2}; // at: {col*img_l,line*img_h};
		draw shape border: #black color: #transparent;
		if(display_info){
			draw rectangle(17,5) at: #user_location+{7,0} border: #black color: #yellow;
			draw ma_description at: #user_location color: #red;
		}
	}
}



experiment test type: gui {
	output {
		//Boutons d'action
		display action_button name:"Actions" ambient_light:100 	{
			species bouton aspect:normal ;
			
			// activer le bouton cliqué
			event mouse_down action: {ask bouton  {do activate;}};

			// afficher le texte quand survolé
			event mouse_move action: {ask bouton {do inform;}};
			
		
		}
	}
}
