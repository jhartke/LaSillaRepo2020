# redefosc2.cl - Procedure to reduce EFOSC2 dithered images
#
# Operations to be done:
#
# subtract a master dark frame
# computes and applied master flat field
# derive proper sky image for each observations and subtract it from 
# raw data
# recenter dithered frames and combine them
#
#
procedure redefosc2(infile, outimage)

	file infile {prompt = 'List of input images'}
        file outimage {prompt = 'Output combined image name'}
	file mdark {prompt = 'File with the master dark'}
        file mflat {prompt = 'File with master flat'}
        file mfrng {prompt = 'File with master fringe image'}
        string sky {"[281:630,101:400]", prompt = 'Area where to compute sky?'}
        bool darkcor {no, prompt = 'Apply Dark Current correction?'}
	bool flatcor {no, prompt = 'Apply Flat Field correction?'}
	bool frngcor {no, prompt = 'Apply Fringe correction?'}
        bool skycor {yes,  prompt = 'Apply background subtraction?'}
        file offlist {prompt = 'Insert offset list [pxl pxl]'}
	bool crocor {yes, prompt = 'Apply cross-correction for alignments?'}
	string cmode {"median", prompt = 'Median or Average stack?'}

begin
	file inputList, listoff, outim
	file masterDark, masterFlat, masterFrng, xyref0
	file procList, dList, dfList, dfsList
	file statList, skyList, wcsList, ccList
        string str1, skyzone, firstFile
	real flatMedian, skyMedian
	file arcpxl1,arcpxl2,headra,headdec
	file refpxl1,refpxl2

outim = outimage
masterDark = mdark
masterFlat = mflat
masterFrng = mfrng
inputList = infile

procList = inputList//".tmp"
dList = inputList//".tmpd"
dfList = inputList//".tmpdf"
dfsList = inputList//".tmpdfs"
statList = inputList//".tmpstat"
skyList = inputList//".tmpsky"
wcsList = inputList//".tmpwcs"
ccList = inputList//".tmpcc"
skyzone = sky
listoff=offlist
xyref0="ref_star.xy"

# creates list of names

!rm medsky*

del(outim//".fits",ver-)
del(outim//"sky.fits",ver-)
del(procList, ver-)
del(dList, ver-)
del(dfList, ver-)
del(dfsList, ver-)
del(statList, ver-)
del(skyList, ver-)
del(wcsList, ver-)
del(ccList, ver-)
#arcpxl1=-1.8333E-04
#arcpxl2=1.8333E-04
#refpxl1=512
#refpxl2=512

firstFile=""
list=inputList
while (fscan (list, str1) != EOF){

   # store name of first file in the list for later use
   if(firstFile=="") {firstFile = str1//"" } 

   # fills all the relevant file distribution lists
   
   print (str1//"", >> procList)
   print (str1//"D", >> dList)
   print (str1//"DF", >> dfList)
   print (str1//"DFS", >> dfsList)
   print (str1//"DF"//skyzone, >> statList)
   print (str1//"DFSKY", >> skyList)
   print (str1//"WCS", >> wcsList)
   print (str1//"CC", >> ccList)

   # Add a raw astrometry calibration
  # keypar(str1,"RA")
  # headra=keypar.value
  # keypar(str1,"DEC")
  # headdec=keypar.value
  # hedit(str1,"CRVAL1",headra,verify-)
  # hedit(str1,"CRVAL2",headdec,verify-)
  # hedit(str1,"CRPIX1",refpxl1,verify-)
  # hedit(str1,"CRPIX2",refpxl2,verify-)
  # hedit(str1,"CDELT1",arcpxl1,verify-)
  # hedit(str1,"CDELT2",arcpxl2,verify-)
  # hedit(str1,"CTYPE1","RA---TAN",verify-)
  # hedit(str1,"CTYPE2","DEC--TAN",verify-)
}
del("*D.fits", ver-)
del("*DF.fits", ver-)
del("*DFS.fits", ver-)
del("*DFSKY.fits", ver-)
del("*WCS.fits", ver-)
del("*CC.fits", ver-)
del(xyref0,ver-)

#
# if requested subtract dark current using the provided frame
#
if (darkcor == yes){
   #subtract dark from all images -- it is assumed the dark is already normalized to the
   # correct exptime

   imarith ("@"//procList,"-", masterDark, "@"//dList)
     
   print ("========== dark correction applied ==========")

}else{
   #subtract dark from all images -- it is assumed the dark is already normalized to the
   # correct exptime

   imarith ("@"//procList,"-",0., "@"//dList)
     
   print ("========== dark correction NOT applied ==========")

}
#
# now apply master flat normalization
#
if (flatcor == yes) {
      imarith ("@"//dList,"/",masterFlat,"@"//dfList)

      print ("=========== flat correction applied: FLAT ", masterFlat, " USED ============")

}else{
      imarith ("@"//dList,"/",1.,"@"//dfList)

      print ("=========== flat correction NOT applied ============")

}

if (frngcor == yes) {
      imarith ("@"//dfList,"-",masterFrng,"@"//dfList)

      print ("=========== fringe correction applied: FRINGE IMAGE ", masterFrng, " USED ============")
}else{
      imarith ("@"//dfList,"-",0.,"@"//dfList)

      print ("=========== fringe correction NOT applied ============")

}


#
# Now subtract the sky
#
if (skycor == yes){

   # combine frames to create master background frame
   imcombine ("@"//dfList, "medsky", combine="median", scale="median", statsec=skyzone,offset="none")
   imcopy ("medsky",outim//"sky")
 
   # retrive median value of the background frame to normalize it

   del ("medsky.tmp", ver-)
   imstat ( "medsky"//skyzone, fields="midpt", > "medsky.tmp")
   fields("medsky.tmp",1,lines=2) | average
   skyMedian = average.sum

   # normalize background frame to 1 dividing for its median value
   imarith ("medsky","/",skyMedian,"medsky")

   print ("======== statistics of the normalized background frame =========")
   imstat ("medsky"//skyzone)

   # store median values of each frame 
   # (used to normalize the master background frame)

   del ("midpt.dat", ver-)
   imstat ("@"//statList,field="midpt",format=no,> "midpt.dat") 

   # here the background (stored in medsky) is scaled to the median of each frame 

   imarith ("medsky","*","@midpt.dat", "@"//skyList )

   # background is subtracted

   imarith ("@"//dfList,"-", "@"//skyList, "@"//dfsList)

   print ("========== background subtraction applied ==========")

}else{
   del ("midpt.dat", ver-)
   imstat ("@"//statList,field="midpt",format=no,> "midpt.dat")
    
   imarith ("@"//dfList,"-","@midpt.dat", "@"//dfsList)
   print ("========== background subtraction NOT applied ==========")
}

imdel (outim)

if (crocor==yes){

   # wregister ("@"//dfsList, firstFile , "@"//wcsList, fitgeom="shift", wcs="world" )
   # print ("========== images registered using keywords ==========")
   # display(firstFile//"WCS",1,fill+)
   # print("... choose objects of reference for fine recentering")
   # print("... mark objects with ',' then exit with q")
   # delete(xyref0)
   # delete("imexam.dat")
   # imexamine(firstFile//"WCS",keeplog=no, > "imexam.dat")
   # fields("imexam.dat", fields="1,2",> xyref0) 
   # tvmark(coor=xyref0, fra=1, mark="circle", rad=30)

   imcopy("@"//dfsList,"@"//wcsList)
   del("dao.out",ver-)
   del("temp.dat",ver-)
   imstat(firstFile//"WCS",fields="stddev",nclip=3,lsigma=3.,usigma=3.,>"temp.dat")
   tabpar("temp.dat",1,1)
   skyMedian=real(tabpar.value)
   del("temp.dat",ver-)
   
   findpars.nsigma=2.
   findpars.sharplo=0.3
   findpars.sharphi=0.8
   findpars.thresho=20.
   datapars.sigma=skyMedian
   datapars.fwhmpsf=5.
   datapars.datamin=INDEF
   datapars.datamax=10000.
   daofind(firstFile//"WCS",output="dao.out",verify-)
   !sed -i '/INDEF/d' dao.out
   !awk '{print $1" "$2}' dao.out > tmp.xy
   tcalc("tmp.xy","dist","sqrt((c1-512.)*(c1-512.)+(c2-512.)*(c2-512.))")
   tsort("tmp.xy","dist",ascend+,casesen+)
   
   fields("tmp.xy", fields="1,2",> "tmp.list")
   mv("tmp.list",xyref0)

   imdel (outim)

   imalign ("@"//wcsList, firstFile//"WCS", xyref0, "@"//ccList, shifts=listoff, boxsize=21,bigbox=91)

   imcombine ("@"//ccList, outim, combine=cmode, offset="none")

}else{
# combine final image recentering each frame according to the offset list

imcombine ("@"//dfsList, outim, combine=cmode, offsets=listoff)

}
end
