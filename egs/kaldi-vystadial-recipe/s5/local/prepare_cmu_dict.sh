#!/bin/bash

source conf/train_conf.sh

locdata=$1; shift
locdict=$1; shift


if [ ! -z "${DICTIONARY}" ]; then
  echo "Using predefined dictionary: ${DICTIONARY}"
  echo '</s>' > $locdata/vocab-full.txt
  tail -n +3 $DICTIONARY | cut -f 1 |\
    sort -u >> $locdata/vocab-full.txt 
else 
  cut -d' ' -f2- data/train/text | tr ' ' '\n' | sort -u > $locdata/vocab-full.txt
fi

if [ ! -z "${NOOOV}" ]; then
  # NOT ALLOWING OOV WORDS training & also in decoding
  echo; echo "REMOVING OOV WORD FROM LANGUAGE MODEL"; echo
  pushd data/local
  grep -v -w OOV lm.arpa > lm.arpa_NO_OOV 
  mv lm.arpa_NO_OOV lm.arpa
  popd
else
  echo; echo "KEEPING OOV WORD IN LANGUAGE MODEL"; echo
fi


if [ ! -f $locdict/cmudict/cmudict.0.7a ]; then
  echo "--- Downloading CMU dictionary ..."
  mkdir -p $locdict 
  svn co http://svn.code.sf.net/p/cmusphinx/code/trunk/cmudict \
    $locdict/cmudict || exit 1;
fi

echo "--- Striping stress and pronunciation variant markers from cmudict ..."
perl $locdict/cmudict/scripts/make_baseform.pl \
  $locdict/cmudict/cmudict.0.7a /dev/stdout |\
  sed -e 's:^\([^\s(]\+\)([0-9]\+)\(\s\+\)\(.*\):\1\2\3:' > $locdict/cmudict-plain.txt

echo "--- Searching for OOV words ..."
gawk 'NR==FNR{words[$1]; next;} !($1 in words)' \
  $locdict/cmudict-plain.txt $locdata/vocab-full.txt |\
  egrep -v '<.?s>' > $locdict/vocab-oov.txt

gawk 'NR==FNR{words[$1]; next;} ($1 in words)' \
  $locdata/vocab-full.txt $locdict/cmudict-plain.txt |\
  egrep -v '<.?s>' > $locdict/lexicon-iv.txt

wc -l $locdict/vocab-oov.txt
wc -l $locdict/lexicon-iv.txt

###  BEGIN SKIPPING GENERATING PRONUNCIACIONS FOR OOV WORDS ####
# pyver=`python --version 2>&1 | sed -e 's:.*\([2-3]\.[0-9]\+\).*:\1:g'`
# if [ ! -f tools/g2p/lib/python${pyver}/site-packages/g2p.py ]; then
#   echo "--- Downloading Sequitur G2P ..."
#   echo "NOTE: it assumes that you have Python, NumPy and SWIG installed on your system!"
#   wget -P tools http://www-i6.informatik.rwth-aachen.de/web/Software/g2p-r1668.tar.gz
#   tar xf tools/g2p-r1668.tar.gz -C tools
#   cd tools/g2p
#   echo '#include <cstdio>' >> Utility.hh # won't compile on my system w/o this "patch"
#   python setup.py install --prefix=.
#   cd ../..
#   if [ ! -f tools/g2p/lib/python${pyver}/site-packages/g2p.py ]; then
#     echo "Sequitur G2P is not found - installation failed?"
#     exit 1
#   fi
# fi
# 
# if [ ! -f conf/g2p_model ]; then
#   echo "--- Downloading a pre-trained Sequitur G2P model ..."
#   wget http://sourceforge.net/projects/kaldi/files/sequitur-model4 -O conf/g2p_model
#   if [ ! -f conf/g2p_model ]; then
#     echo "Failed to download the g2p model!"
#     exit 1
#   fi
# fi
# 
# echo "--- Preparing pronunciations for OOV words ..."
# python tools/g2p/lib/python${pyver}/site-packages/g2p.py \
#   --model=conf/g2p_model --apply $locdict/vocab-oov.txt > $locdict/lexicon-oov.txt

