package npTranscript.run;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.OutputStreamWriter;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import japsa.bio.np.barcode.SWGAlignment;
import japsa.seq.Alphabet;
import japsa.seq.Sequence;
import japsa.seq.SequenceOutputStream;
import japsa.seq.SequenceReader;
import japsa.util.CommandLine;
import japsa.util.deploy.Deployable;

@Deployable(scriptName = "npConsensus.run", scriptDesc = "Analysis of consensus")
public class ConsensusMapper extends CommandLine {

	static SequenceOutputStream os;
	
	public ConsensusMapper() {
		super();
		Deployable annotation = getClass().getAnnotation(Deployable.class);
		setUsage(annotation.scriptName() + " [options]");
		setDesc(annotation.scriptDesc());
		addString("fasta", null, "Name of consensus fasta file", true);
		addString("reference", null, "Name of reference genome", true);
		addInt("offset",0, "offset to add from breakpoints",false); // this included for earlier versions of npTranscript
		addStdHelp();

	}
	public static void main(String[] args1) throws IOException, InterruptedException {
		CommandLine cmdLine = new ConsensusMapper();
		String[] args = cmdLine.stdParseLine(args1);

		String fasta = cmdLine.getStringVal("fasta");
		String reference = cmdLine.getStringVal("reference");
		int offset = cmdLine.getIntVal("offset");
		run(fasta, reference, offset);
	}
	static Pattern p1 = Pattern.compile("-{1,}"); 
	static Pattern p2 = Pattern.compile("-{2,}"); //consider two or more to be deletion

	static Pattern p3 = Pattern.compile("-{3,}"); //consider two or more to be deletion
	
	static class Indel{
		int start;
		int len;
		//int len;
		Indel(int start, int len){
			this.start = start;
			this.len = len;
		}
		public String toString(){
			if(len==1) return start+"";
			else return start+"-"+len;
		}
	}
	//getString(List<Indel>)
	static int getGaps(char[] seq, Pattern p, List<Indel> allMatches){
		String seqr = new String(seq);
		Matcher m = p.matcher(seqr);
		int tot =0;
		while (m.find()) {
				int len =  m.end()-m.start();
				tot+=len;
			   allMatches.add(new Indel(m.start(),len));
		}
		return tot;
	}
	
	/** removes positions in first sequence which cause gaps in second sequence */
	private static String removeGapsInRef(char[] seq1, char[]  seqRef,List<Indel> gaps, int startInRef) {
		if(seq1.length!=seqRef.length) throw new RuntimeException("!!");
		gaps.clear();
		int gap = getGaps(seqRef,p1, gaps);
		char[] seq1_new = new char[seq1.length - gap];
		int st =0;
		int target_st =0;
		int total_gap =0;
		for(int i=0; i<gaps.size(); i++){
			Indel indel = gaps.get(i);
			int end = indel.start; // end of previous non gapped sequence
			int len = end-st;
			if(len>0){
				for(int j=0; j<len; j++){
					seq1_new[target_st +j] = seq1[st+j]==seqRef[st+j] ? seq1[st+j] : lower(seq1[st+j]);
				}
				//System.arraycopy(seq1, st, seq1_new, target_st, len);
				target_st+=len;
			}
			st = end+ indel.len;
			indel.start = indel.start-total_gap+startInRef;  // adjust indel so that start position now is in ref coords (i.e. remove total_gap
			total_gap+=indel.len;
		}
		if(st < seqRef.length){
			int len = seqRef.length - st;
			for(int j=0; j<len; j++){
				
				seq1_new[target_st +j] = seq1[st+j]==seqRef[st+j] ? seq1[st+j] : lower(seq1[st+j]);
			}
			//System.arraycopy(seq1, st, seq1_new, target_st, len);
		}
		return new String(seq1_new);
	}
	
	
	private static char lower(char c) {
		return (new String(new char[] {c})).toLowerCase().charAt(0);
	}
	private static void run(String fasta, String refFile, int offset) throws IOException {
		// TODO Auto-generated method stub
		ArrayList<Sequence> genomes = SequenceReader.readAll(refFile, Alphabet.DNA());
		List<String> header = Arrays.asList(
				"ID      chrom start   end     type_nme        startBreak      endBreak        isoforms        leftGene        rightGene       totLen  countTotal".split("\\s+")
		);
		int genome_index = Integer.parseInt(fasta.split("\\.")[0]);
		Sequence refSeq = genomes.get(genome_index);
		ArrayList<Sequence> reads = SequenceReader.readAll(fasta, Alphabet.DNA());
		SWGAlignment align; 
		
		File fasta_in = new File(fasta);
		File fasta_out = new File(fasta_in.getParentFile(), fasta+".corrected.fa");
		OutputStreamWriter os1 = new OutputStreamWriter(new FileOutputStream(fasta_out));
	
		//SequenceOutputStream os =new SequenceOutputStream(os1);
		int step = 100;
		for(int i=0; i< reads.size(); i++){
			Sequence readSeq = reads.get(i);
			String nme = readSeq.getName();
			String[] desc = readSeq.getDesc().split(";"); //ID0.0;MT007544.1;1;29893;5_3;22;27904;2;leader;ORF8;-1;2262
			int start = Integer.parseInt(desc[header.indexOf("start")]); 
			int end = Integer.parseInt(desc[header.indexOf("end")]);
			int startBr = Integer.parseInt(desc[header.indexOf("startBreak")]);
			int endBr = Integer.parseInt(desc[header.indexOf("endBreak")]);
			String leftGene = 			desc[header.indexOf("leftGene")];
			String rightGene = 			desc[header.indexOf("rightGene")];

			
			
			int right_offset = endBr - offset;
			
			SWGAlignment right_align = SWGAlignment.align(readSeq, refSeq.subSequence(right_offset, refSeq.length()));
			int right_start1 = right_align.getStart1();
			int right_end1 = right_start1 + right_align.getSequence1().length - right_align.getGaps1();
			
			SWGAlignment left_align = SWGAlignment.align(readSeq.subSequence(0, right_start1-1), refSeq.subSequence(0, startBr+offset));
		
			double identL = (double) left_align.getIdentity()/(double) left_align.getLength();
			
			//start_end on read
			int left_start1 = left_align.getStart1();
			int left_end1 = left_start1 + left_align.getSequence1().length - left_align.getGaps1();
			
			System.err.println(left_start1+","+left_end1+","+right_start1 +","+right_end1);
			if(right_start1 < left_end1) {
				throw new RuntimeException("problem");
			}
			
			
			int left_start = left_align.getStart2();
			int left_end = left_start + left_align.getSequence2().length - left_align.getGaps2();
			double identR = (double) right_align.getIdentity()/(double) right_align.getLength();
			int right_start = right_align.getStart2() + right_offset;
			int right_end = right_start + right_align.getSequence2().length - right_align.getGaps2();
			List<Indel> gaps1 = new ArrayList<Indel>(); //insertions relative to reference
			List<Indel> gaps2 = new ArrayList<Indel>();
			String sequ1 = removeGapsInRef(left_align.getSequence1(), left_align.getSequence2(),gaps1, left_start);
			String sequ2 =removeGapsInRef(right_align.getSequence1(), right_align.getSequence2(), gaps2, right_start);
			String sequ2_refonly = (new String(right_align.getSequence2())).replaceAll("-", "");
		if(sequ2.length()!=sequ2_refonly.length()) throw new RuntimeException("this should not happen");
			os1.write(">"+readSeq.getName()+".L"+" "+left_start+","+left_end+" "+readSeq.getDesc()+" "+gaps1.toString().replaceAll("\\s+", "")+"\n");
			for(int j=0; j<sequ1.length(); j+=step){
				os1.write(sequ1.substring(j, Math.min(sequ1.length(), j+step)));
				os1.write("\n");
			}
			os1.write(">"+readSeq.getName()+".R"+" "+right_start+","+right_end+" "+readSeq.getDesc()+" "+gaps2.toString().replaceAll("\\s+", "")+"\n");
			for(int j=0; j<sequ2.length(); j+=step){
				os1.write(sequ2.substring(j, Math.min(sequ2.length(), j+step)));
				os1.write("\n");
			}
		}
		os1.close();
	}
	
}
