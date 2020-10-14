/*
 * 
 * Copyright 2020 Jonathan Luisi 
 * 
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 * 
 *   http://www.apache.org/licenses/LICENSE-2.0 
 *   
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 * 
 * 
 * README: to run on batch run BatchReadOCT seperately
 * Running script will start with make projection on registed B-scans
 * 	*user intervention only required to select ILM and project every 60um slab 
 * 	*Values are set for mouse reinal imaging bu can be adapted for different aquisition parameters
 * 
 */
 
macro "make Projection" {
	list = getList("image.titles");
	if (list.length==0){
		Dialog.create("Pick Files to open");
		
	  		OpenItems = newArray("Single", "Batch","Cancel");
	  		Dialog.addRadioButtonGroup("Select OCT files", OpenItems, 3, 1, "Single");
	  		Dialog.show;
	  		SelectOpenItems = Dialog.getRadioButton;
	  		if (SelectOpenItems == "Single") {
	  			OCTname = File.openDialog("Choose OCT File");
	  			ReadOCT(OCTname);
	  		}else if (SelectOpenItems == "Batch") {
	  			print("Batch Read");
	  			BatchReadOCT();
	  		}else {
	  			exit();
	  		}
		
	}		//end list length 
    else {
		/*
		 * Image open make OCTA options
		 */
		
		imgName = getTitle();
		rawimgID = getImageID();
		step = 30;
    	Stack.getDimensions(iWidth, iHeight, iChannels, iMAXslice, iFrames);
		print(iWidth + " max " + iMAXslice + " frames " + iFrames);
		
		Dialog.create("OCTA");
		Dialog.addChoice("OCT Image Type:", newArray("B-Scan", "EnFace", "Vessel"));
		//Dialog.addCheckbox("Use Averaging", false);
  		items = newArray("None", "Average", "STDEV","Composite");
  		Dialog.addRadioButtonGroup("Use Frame Averaging Method", items, 1, 3, "None");
  		Dialog.addRadioButtonGroup("OCTA Projection Method ", newArray("ColorCoded", "StandardDeviation", "None"), 1, 3, "ColorCoded");
  		//Dialog.addCheckbox("OCTA Color Projection", true);
  		Dialog.addCheckbox("Also Make Montage", true);
  		Dialog.addNumber("Projection Step Size", step)
  		Dialog.show;
  		OCT_Type = Dialog.getChoice();
  		//Averageing = Dialog.getCheckbox();
  		projection = Dialog.getRadioButton;
  		//ProjectionColor = Dialog.getCheckbox();
  		ProjectionColor = Dialog.getRadioButton;
  		ColorMontage = Dialog.getCheckbox();
  		step = Dialog.getNumber();
  		if (OCT_Type == "B-Scan") {
  			
	  		if (projection == "Average")
	  		{
	  			AVE_Project();
	  			imgName = "AVE_" + imgName;
	  			rename(imgName);
	  		}
	  		else if (projection == "STDEV"){
	  			//standard deviation 
	  			STDEV_Project();
	  			imgName = "STDEV_" + imgName;
	  			rename(imgName);
	  		}
	  		else if(projection == "Composite"){
	  			selectImage(rawimgID);
	  			
	  			AVE_Project();
	  			
				run("Reslice [/]...", "output=1.400 start=Top avoid");
				run("Subtract...", "value=20 stack");
	  			rename("Raw");
	  			RAW_ID = getTitle();
	  			run("Duplicate...", "duplicate");
	  			
	  			imgName = "AVE_" + imgName;
	  			rename(imgName);
	  			OCTA_Filter();
	  			AVE_ID= getTitle();

	  			selectImage(rawimgID); 
	  			STDEV_Project();
				run("Reslice [/]...", "output=1.400 start=Top avoid");
				run("Subtract...", "value=20 stack");
	  			imgName = "STDEV_" + imgName;
	  			rename(imgName);
	  			OCTA_Filter();
	  			STDEV_ID = getTitle();

	  			run("Merge Channels...", "c1=" + STDEV_ID + " c2=" + AVE_ID + " c4=" + RAW_ID + " create");
	  			
	  			rename("CompositeOCTA_" + imgName);

	  			
	  			exit();
	  		}	//end composite
			
			
			run("Reslice [/]...", "output=1.400 start=Top avoid");
			run("Subtract...", "value=20 stack");
  		}
		
		if (OCT_Type != "Vessel") {
			
			OCTA_Filter();
			
			rename("OCTA_Filter_"+ imgName);
		}

		if (ProjectionColor == "ColorCoded") 
		{
			myImageID = getImageID(); 
			run("Orthogonal Views");
			Stack.getDimensions(width, height, channels, MAXslice, frames);
			waitForUser("Set Start Slice");
			selectImage(myImageID);
			Stack.getPosition(channel, slice, frame);
			do {
				projectOCTA(slice, step);
				selectImage(myImageID);
				slice = slice + step;
			} while (slice <= (MAXslice -step));
			run("Images to Stack");
			rename("OCTA_Stack_" + imgName);
			run("Scale Bar...", "width=200 height=5 font=18 color=White background=None location=[Lower Right] bold hide label");
			if (ColorMontage == true) {
				run("Make Montage...", "columns=3 rows=2 scale=1 last=6 border=3");
				rename("OCTA_M_" + imgName);
				}	//end montage
		}	// end color projection
		else if (ProjectionColor == "StandardDeviation")	
			{
				
			myImageID = getImageID(); 
			run("Median 3D...", "x=3 y=3 z=2");
			//run("Orthogonal Views");
			Stack.getDimensions(width, height, channels, MAXslice, frames);
			waitForUser("Set Start Slice");
			selectImage(myImageID);
			Stack.getPosition(channel, slice, frame);
			do {
				StopSlice = slice + step;
				run("Z Project...", "start=" +slice +" stop=" + StopSlice + " projection=[Standard Deviation]");
				run("8-bit");
				selectImage(myImageID);
				slice = StopSlice;
			} while (slice <= (MAXslice -step));
			run("Images to Stack");
			rename("OCTA_Stack_" + imgName);
			run("Scale Bar...", "width=200 height=5 font=18 color=White background=None location=[Lower Right] bold hide label");
			if (ColorMontage == true) {
				run("Make Montage...", "columns=3 rows=2 scale=1 last=6 border=3");
				rename("OCTA_M_" + imgName);
				}	//end montage
				
			}//end of 
			
	    }	    //Make OCTA
}
function OCTA_Filter(){
	/*
	 * input is a En-face image 
	 * output is 3D vessel enhanced image 
	 */

	startTime = getTime();
	
	run("Bandpass Filter...", "filter_large=40 filter_small=3 suppress=Horizontal tolerance=5 autoscale process");
	
	run("Gaussian Blur...", "sigma=2 scaled stack");			//as published 
	
	//run("Median 3D...", "x=5 y=5 z=3");						//slow
	
	//run("Gaussian Blur 3D...", "x=3 y=3 z=2");				//moderate gains
	
	run("Convolve...", "text1=[1 2 -2 4 -2 2 1\n2 4 -4 -16 -4 4 2\n-2 -4 4 16 4 -4 -2\n -8 -16 16 64 16 -16 8\n-2 -4 4 16 4 -4 -2\n2 4 -4 -16 -4 4 2\n1 2 -2 4 -2 2 1\n] normalize stack");
	/*
	 * Frangi works best here but performance suffers
	 */	
	//run("Frangi Vesselness (imglib, experimental)", "number=1 minimum=3.000000 maximum=3.000000");
	//run("Median 3D...", "x=3 y=3 z=2");
	//run("8-bit");
	run("Smooth", "stack");
	run("Subtract Background...", "rolling=30 stack");
	
	stopTime = getTime();
	print("OCTA RunTime: " + (stopTime - startTime)/1000);
}	//OCTA with bandpass step 

function projectOCTA(slice, stepSize){
	/*
	 * starts from an OCTA volume, projects a slab with thickness specified by "stepsize"
	 */
	run("Duplicate...", "duplicate range="+ slice + "-" + (slice + stepSize));
	tempIMG = getImageID(); 
	run("Stack to Hyperstack...", "order=xyctz channels=1 slices=" + (stepSize+1) + " frames=1 display=Color");
	run("Temporal-Color Code", "lut=Fire start=1 end=31");
	run("Enhance Local Contrast (CLAHE)", "blocksize=127 histogram=256 maximum=3 mask=*None*");
	run("Properties...", "unit=µm pixel_width=1.4 pixel_height=1.4 voxel_depth=1.4");
	rename(slice + "-" + (slice + stepSize)+ "_OCTA");
	selectImage(tempIMG);
	close();
} //end of project OCTA

function AVE_Project(){
	/*
	 * Mean Averaging of image used to project
	 */
	run("Grouped Z Project...", "projection=[Average Intensity] group=3");
	run("8-bit");
	run("Properties...", "unit=µm pixel_width=1.4 pixel_height=1.9 voxel_depth=1.4");	
}

function STDEV_Project(){
	/*
	 * Standard Deviation of image used to project
	 */
	run("Grouped Z Project...", "projection=[Standard Deviation] group=3");
	run("8-bit");
	run("Properties...", "unit=µm pixel_width=1.4 pixel_height=1.9 voxel_depth=1.4");	
}

function BatchReadOCT() {
	/*
	 * This reads and conversts the bioptigen raw .OCT data format into usable Tiff stacks 
	 */
	tmpdir= getDirectory("Choose a Directory");
	if (!File.exists(tmpdir))
	{
		exit();
		// directory error no point
	}
	list = getFileList(tmpdir);
	
	setBatchMode(true);
	
	OutputDir = tmpdir+"Output_Vol_tiff"+File.separator;
	if (!File.exists(OutputDir)){
		File.makeDirectory(OutputDir);
		//print("Directory Created", OutputDir);
	}
	
	counter = 0; 
	print ("File List size= " + list.length);
	for (i=0; i<list.length; i++)
	{
		//convert .oct files 
		if (endsWith(list[i], ".OCT")){
			print("file " + list[i] + " number: " + i);
			getDateAndTime(year, month, week, day, hour, min, sec, msec);
			print( "Time"+toString(hour)+":"+toString(min) );
			ReadOCT(tmpdir + list[i]);
			saveAs("Tiff", OutputDir + "Output_" + list[i] + ".tiff");
			close();
			counter = counter + 1 ;
			print("finished, converted files: " + counter + " of " + list.length);
		} 
	}	
	print("finished all, converted " + counter + " of " + list.length);
	setBatchMode(false);
} // end of batch read
function ReadOCT(OCTname) {
	/*
	 * Basic OCT reader for Bioptigen 
	 * Requires Bioptigen reader 
	 */
	//print(OCTname);
	run("OCT Reader", "select=["+ OCTname + "]");
	run("Flip Vertically", "stack");
	run("Reverse");
	//image is now correctly oriented to fundus views when reslicing 
	Stack.getDimensions(iWidth, iHeight, iChannels, iMAXslice, iFrames);
	print(iWidth + " max " + iMAXslice + " frames " + iFrames);
	makeRectangle(0, 105, iWidth, 558);	//crops likely imaged region - assumtion that retina is in top 3/4 
	run("Crop");
	
	run("Gamma...", "value=2 stack"); //gamma = 2 closest to bioptigen display
	setSlice(round(nSlices / 2));
	run("StackReg", "transformation=[Rigid Body]");
	run("Properties...", "unit=µm pixel_width=1.4000 pixel_height=1.9000 voxel_depth=1.4000");

}

