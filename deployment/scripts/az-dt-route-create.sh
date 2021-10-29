adtname=$1
rgname=$2
epname=$3
rtname=$4

# install/update azure iot az cli extension
az extension add --name azure-iot -y

rttest=$(az dt route show --dt-name $adtname --rn "$rtname" 2> null)
if [ -z $rttest];
then
  az dt route create --dt-name $adtname --endpoint-name "$epname" --route-name "$rtname"
else
  echo 'route exists, skipping creation'
fi