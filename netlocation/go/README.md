# Instructions for building and running a statically linked netlocation go container
# 
# On  your mac
cd <your_ asteere/ad-nimbus>
git pull origin aws_proto

# Note 1: I rearranged the src code to reflect the github.com hierarchy
# Note 2: These commands that the ad-nimbus/.hostProfile file has been sourced
cdad
cd netlocation/go

# Build netlocation statically
docker run --rm -e "CGO_ENABLED=0" -e "GOOS=linux" -v "$PWD":/go -w /go golang:1.3-onbuild go install -a -ldflags '-a' github.com/mark-larter/netlocation

# Validate that there is a new location
ls l bin

# Create the scratch or empty container
tar cv --files-from /dev/null | docker import - asteere/empty:empty

# Build the empty container and add statically linked netlocation.go
docker build -t asteere/netlocation-go:netlocation-go .

# Save the docker image to a tar file so that Vagrant can see it or you can scp it to AWS
docker save -o $adNimbusDir/registrySaves/netlocation-go.tar asteere/netlocation-go:netlocation-go

# Smaller is good
gzip -f $adNimbusDir/registrySaves/netlocation-go.tar

# On a Vagrant or AWS instance
docker load -i $adNimbusDir/registrySaves/netlocation-go.tar.gz

docker run -p 49160:49160 asteere/netlocation-go:netlocation-go
