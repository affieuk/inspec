# THIS IS NOW HAND MANAGED, JUST EDIT THE THING

# grab the current train release from rubygems.org
train_stable = /^train \((.*)\)/.match(`gem list ^train$ --remote`)[1]
override "train", version: "v#{train_stable}"
override "ruby", version: "3.1.6"

override :openssl, version: "3.0.9"

override "ruby-msys2-devkit", version: "3.1.6-1"
