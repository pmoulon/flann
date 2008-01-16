module commands.IndexCommand;

import commands.GenericCommand;
import commands.DefaultCommand;
import dataset.Features;
import algo.all;
import output.Console;
import output.Report;
import util.Logger;
import util.Utils;
import util.Profiler;



class IndexCommand : DefaultCommand
{
	public static string NAME = "create_index";
	
	string inputFile;
	string paramsFile;
	string algorithm;
	uint trees;
	uint branching;
	bool byteFeatures;
	string centersAlgorithm;
	int maxIter;
	bool useParamsFile;
	
	protected {
		NNIndex index;
		
		template inputData(T) {
			Features!(T) inputData = null;
		}
		//Features!(ubyte) inputDataByte = null;
	}
	

	this(string name) 
	{
		super(name);
		register(inputFile,"i","input-file", "","Name of file with input dataset.");
		register(paramsFile,"p","params-file", "","File containing 'optimum' input dataset parameters.");
		register(algorithm,"a","algorithm", "","The algorithm to use when constructing the index (kdtree, kmeans...).");
		register(trees,"r","trees", 1,"Number of parallel trees to use (where available, for example kdtree).");
		register(branching,"b","branching", 2,"Branching factor (where applicable, for example kmeans) (default: 2).");
		register(byteFeatures,"B","byte-features", null ,"Use byte-sized feature elements.");
		register(centersAlgorithm,"C","centers-algorithm", "random","Algorithm to choose cluster centers for kmeans (default: random).");
		register(maxIter,"M","max-iterations", int.max,"Max iterations to perform for kmeans (default: until convergence).");		
		register(useParamsFile,"U","use-params-file", null,"Use the file with autotuned params.");		
 		
 		description = "Index the input dataset.";
	}
	
	
	private void executeWithType(T)() 
	{
		report("byte_features", byteFeatures?1:0);
		
		if (inputFile != "") {
			showOperation( "Reading input data from "~inputFile, {
				inputData!(T) = new Features!(T)();
				inputData!(T).readFromFile(inputFile);
			});
		}
		
		report("dataset", inputFile);
		report("input_count", inputData!(T).count);
		report("input_size", inputData!(T).veclen);
	
		if (inputData!(T) is null) {
			throw new Exception("No input data given.");
		}
		
		Params params;
		
		if (maxIter==-1) {
			maxIter = int.max;
		}
				
		if (useParamsFile) {
			if (paramsFile == "") {
				paramsFile = inputFile~".params";
				logger.info("No params file given, trying "~paramsFile);
			}
			
			try {
				params.load(paramsFile);
			}
			catch(Exception e) {
				logger.warn("Cannot read params from file"~paramsFile);
			}
		} else {
			params["trees"] = trees;
			params["branching"] = branching;
			params["centers-algorithm"] = centersAlgorithm;
			params["max-iterations"] = maxIter;
			params["algorithm"] = algorithm;
		}
		
		report("trees", params["trees"]);
		report("branching", params["branching"]);
		report("max_iterations", params["max-iterations"]);
		report("algorithm", params["algorithm"]);
		
		string algorithm = params["algorithm"].get!(string);
		
		if (!(algorithm in indexRegistry!(T))) {
			logger.error("Algorithm not supported.");
			logger.error("Available algorithms:");
			foreach (algo,val; indexRegistry!(T)) {
				logger.error(sprint("\t{}",algo));
			}			
			throw new Exception("Algorithm not found...bailing out...\n");
		}

		logger.info(sprint("Algorithm: {}",algorithm));
		index = indexRegistry!(T)[algorithm](inputData!(T), params);

		logger.info("Building index...");
		float indexTime = profile({
			index.buildIndex();
		});
		
		report("cluster_time", indexTime);
		
		logger.info(sprint("Time to build {} tree{} for {} vectors: {} seconds",
			index.numTrees, index.numTrees == 1 ? "" : "s", index.size, indexTime));

// 		if (saveFile !is null) {
// 			Logger.log(Logger.INFO,"Saving index to file %s... ",saveFile);
// 			fflush(stdout);
// 			index.save(saveFile);
// 			Logger.log(Logger.INFO,"done\n");
// 		}
	}
	
	void execute() 
	{
		if (byteFeatures) {
			executeWithType!(ubyte)();
		} else {
			executeWithType!(float)();
		}
	}
	
}