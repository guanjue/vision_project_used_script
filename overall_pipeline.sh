script_dir=/storage/home/gzx103/group/software/vision_mouse/src/
working_dir=/storage/home/gzx103/scratch/vision/test_pipeline/
input_dir=/storage/home/gzx103/scratch/vision/test_pipeline/input_5end_rc/
input_file_list=info_table_all.rc2nbp.txt
overall_upper=16
overall_lower=2


cd $working_dir

###### covert reads count to NB p-value
while read LINE
do
	sig1=$(echo "$LINE" | awk '{print $1}')
	sig2=$(echo "$LINE" | awk '{print $2}')
	echo $sig1 $sig2
	time Rscript $script_dir'negative_binomial_p_2r_bgadj.R' $sig1 $input_dir $sig2 $input_dir $sig1
done < $input_file_list



###### convert nbp to Fisher's method merged p-value
### extrac cell type mark list
ls *.nbp_2r_bgadj.txt | awk -F '.' -v OFS='\t' '{print $1"."$2}' | sort -u > cell_marker_list.txt
ls *.nbp_2r_bgadj.txt | awk -F '.' -v OFS='\t' '{print $2}' | sort -u > marker_list.txt
ls *.nbp_2r_bgadj.txt | awk -F '.' -v OFS='\t' '{print $1}' | sort -u > cell_list.txt

### move data NB p-value data into nbp folder
if [ -d $working_dir'nbp/' ]; then echo $working_dir'nbp/' exist; else mkdir $working_dir'nbp/'; fi
mv *.nbp_2r_bgadj.txt $working_dir'nbp/'
mv *.mvsp.txt $working_dir'nbp/'

### get Fisher's method combined pval
for cm in $(cat cell_marker_list.txt)
do
	echo $cm
	Rscript $script_dir'fisher_pval.R' $cm '.nbp_2r_bgadj.txt' $working_dir'nbp/' 100
done



###### select reference dataset for pknorm
for mk in $(cat mark_list.txt)
do
	echo $mk
	ls *$mk*.frip_snr.txt > $mk'.file_list.txt'
	time Rscript $script_dir'get_mk_ref.R' $mk'.file_list.txt' $mk'.ref_frip.txt'
done



###### pknorm normalize reference datasets of all marks
while read LINE
do
	sig1=$(echo "$LINE" | awk '{print $1}')
	sig2=$(echo "$LINE" | awk '{print $2}')
	sig2_celltype=$(echo "$LINE" | awk '{print $2}' | awk -F '.' -v OFS='\t' '{print $1"_"$2}')
	upperlim=100
	lowerlim=0
	echo $sig1 
	echo $sig2
	echo $sig2_celltype
	### set upper limit
	cat $sig1 | awk -F '\t' -v OFS='\t' -v ul=$upperlim '{if ($1>=ul) print ul; else print $1}' > $sig1'.upperlim.txt'
	cat $sig2 | awk -F '\t' -v OFS='\t' -v ul=$upperlim '{if ($1>=ul) print ul; else print $1}' > $sig2'.upperlim.txt' 
	### peak norm
	time python $script_dir'peaknorm_rotate_log_ref_mean.py' -n 500000 -a $sig1'.upperlim.txt' -b $sig2'.upperlim.txt' -u $upperlim -l $lowerlim
done < raw_sig_list.txt




###### pknorm across datasets with the same mark & set limit
for mk in $(cat mark_list.txt)
do
	echo $mk
	while read LINE
	do
		sig1=$(echo "$LINE" | awk '{print $1}')
		sig2=$(echo "$LINE" | awk '{print $2}')
		sig2_celltype=$(echo "$LINE" | awk '{print $2}' | awk -F '.' -v OFS='\t' '{print $1}')
		upperlim=100
		lowerlim=0
		echo $sig1 
		echo $sig2
		echo $sig2_celltype
		### set upper limit for pknorm input
		cat $sig1 | awk -F '\t' -v OFS='\t' -v ul=$upperlim '{if ($1>=ul) print ul; else print $1}' > $sig1'.upperlim.txt'
		cat $sig2 | awk -F '\t' -v OFS='\t' -v ul=$upperlim '{if ($1>=ul) print ul; else print $1}' > $sig2'.upperlim.txt' 
		### peak norm
		time python $script_dir'peaknorm_rotate_log_z_mean.py' -n 500000 -a $sig1'.upperlim.txt' -b $sig2'.upperlim.txt' -u $upperlim -l $lowerlim
		### set upper limit for pknorm output
		cat $sig2_celltype'.pknorm.txt' | awk -F '\t' -v OFS='\t' -v ul=overall_upper -v ll=overall_lower '{if ($1<ll) print ll; else if ($>ul) print ul; else print $1}' > $sig2_celltype'.pknorm.'ll'_'ul'.txt'
		### change file names
		mv $sig2_celltype'.pknorm.txt' $mk'.'$sig2_celltype'.pknorm.txt'
		mv $sig2_celltype'.pknorm.'ll'_'ul'.txt' $mk'.'$sig2_celltype'.pknorm.'ll'_'ul'.txt'
	done < $mk'.pknorm_input_list.txt'
done


