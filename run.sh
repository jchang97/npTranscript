##general script for running analysis
##ASSUMES THE PROJECT IS STORED IN $HOME/github/npTranscript

JSA_MEM=8000m


npTranscript=$HOME/github/npTranscript
classp=$(ls ${npTranscript}/libs | xargs -I {} echo ${npTranscript}/libs/{} )
classpath=$(echo $classp | sed 's/ /:/g')
JSA_CP=${npTranscript}/npTranscript.jar:${classpath}
#echo $JSA_CP



str="java -Xmx${JSA_MEM} -ea -Djava.awt.headless=true -Dfile.encoding=UTF-8 -classpath ${JSA_CP} npTranscript.run.ViralTranscriptAnalysisCmd2 $@"
echo "running .."
echo $str
$str
echo "finished"


