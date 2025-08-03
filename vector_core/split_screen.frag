******[UNIFORMS]******
uniform vec4 kolmicam;

******[FUNCTIONS]******

******[WORLD]******

******[OVERLAY]******

******[OUTPUT]******

//courtesy of Alex

	bool in_CCTV_area = gl_FragCoord.x > window_size.x * 0.7235 && gl_FragCoord.y < window_size.y * 0.687;

	if(kolmicam.x == 1.0){

		if (in_CCTV_area && kolmicam.y == 1.0){
				gl_FragColor.rgb  = color;
				gl_FragColor.a = 1.0;
		}
	
		if (!in_CCTV_area && kolmicam.y != 1.0){
				gl_FragColor.rgb  = color;
				gl_FragColor.a = 1.0;
		}
	} else {
				gl_FragColor.rgb  = color;
				gl_FragColor.a = 1.0;
	}