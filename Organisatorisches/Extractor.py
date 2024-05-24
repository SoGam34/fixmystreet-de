
import json
import argparse
parser = argparse.ArgumentParser()                                               

parser.add_argument("--file", "-f", type=str, required=True)
args = parser.parse_args()

input = open(args.file, 'r', encoding="utf-8")
output = open('output.txt', 'w', encoding="utf-8")

input = json.load(input)

for x, obj in input.items():
    if obj["type"] == 'O08':
        output.write(str(obj["id"])+ '\n')
output.write('\n\n\n # 006 \n\n')
for x, obj in input.items():
    if obj["type"] == 'O06':
        output.write(str(obj["id"])+ '\n')

output.write('\n\n\n\n\n')

for x, obj in input.items():
    if obj["type"] == 'O08':
        output.write(obj["name"]+'\n')

for x, obj in input.items():
    if obj["type"] == 'O06':
        output.write(obj["name"]+'\n')

output.close()

