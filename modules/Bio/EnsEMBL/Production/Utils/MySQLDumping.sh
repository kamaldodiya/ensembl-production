#!/bin/bash --
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2019] EMBL-European Bioinformatics Institute
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License
set -euo pipefail
database=$1
output_dir=$2
host=$3
user=$4
password=$5
port=$6

if [ -d "$output_dir/$database" ]
 then
    rm -r "$output_dir/$database"
fi

mkdir -m 777 -p "$output_dir/$database"

cd "$output_dir/$database"

echo "Dumping $database";

EXCLUDED_TABLES=(
MTMP_probestuff_helper
MTMP_evidence
MTMP_motif_feature_variation
MTMP_phenotype
MTMP_regulatory_feature_variation
MTMP_supporting_structural_variation
MTMP_transcript_variation
MTMP_variation_set_structural_variation
MTMP_variation_set_variation
)
for TABLE in "${EXCLUDED_TABLES[@]}"
do :
   IGNORED_TABLES_STRING+=" --ignore-table=${database}.${TABLE}"
   IGNORED_TABLES_SHOW+="'${TABLE}',"
done
IGNORED_TABLES_SHOW=${IGNORED_TABLES_SHOW%?}
cmd_line_options=""

if [[ $database =~ .*mart.* ]]; then
    cmd_line_options=" --skip-lock-tables"
fi

query="show tables WHERE tables_in_${database} NOT IN (${IGNORED_TABLES_SHOW})"
# echo $query
echo "Dumping sql file for $database";

mysqldump --host=$host --user=$user --password=$password --port=$port ${IGNORED_TABLES_STRING} ${cmd_line_options} -d $database | gzip > ${output_dir}/$database/$database.sql.gz

for t in $(mysql -NBA --host=$host --user=$user --password=$password --port=$port -D $database -e "${query}")
do
    echo "DUMPING TABLE: $database.$t"
    mysql --host=$host --user=$user --password=$password --port=$port -e "SELECT * FROM ${database}.${t}" --quick --silent --raw --skip-column-names > ${output_dir}/$database/$t.txt
    sed -i -e '/NULL/ s//\\N/g' ${output_dir}/$database/$t.txt
    echo "GZipping text files"
    gzip -nc "$output_dir/$database/$t.txt" > "$output_dir/$database/$t.txt.gz"
    rm -f "$output_dir/$database/$t.txt" 2> /dev/null
done

echo "Creating CHECKSUM for $database"
find  -type f -name '*.gz' -printf '%P\n' | while read file; do
    sum=$(sum $file)
    echo -ne "$sum\t$file\n" >> CHECKSUMS
done