export APP_MONERO_IP="10.21.22.178"
export APP_MONERO_NODE_IP="10.21.21.179"
export MONEROD_IP="10.21.21.179"
export APP_MONERO_TOR_PROXY_IP="10.21.21.180"
export APP_MONERO_I2P_DAEMON_IP="10.21.21.181"
export APP_MONERO_RPC_USER="monero"
export APP_MONERO_RPC_PASS="monero"

export APP_MONERO_DATA_DIR="${EXPORTS_APP_DIR}/data/monero"
export APP_MONERO_RPC_PORT="18081"
export APP_MONERO_P2P_PORT="18080"
export APP_MONERO_TOR_PORT="9901"
export APP_MONERO_RPC_HIDDEN_SERVICE="notyetset.onion"
export APP_MONERO_P2P_HIDDEN_SERVICE="notyetset.onion"

MONERO_CHAIN="main"
MONERO_ENV_FILE="${EXPORTS_APP_DIR}/.env"

{
	MONERO_APP_CONFIG_FILE="${EXPORTS_APP_DIR}/data/app/monero-config.json"
	if [[ -f "${MONERO_APP_CONFIG_FILE}" ]]
	then
		monero_app_network=$(jq -r '.network' "${MONERO_APP_CONFIG_FILE}")
		case $monero_app_network in
			"main")
				MONERO_NETWORK="mainnet";;
			"test")
				MONERO_NETWORK="testnet";;
			"stagenet")
				MONERO_NETWORK="stagenet";;
		esac
	fi
} > /dev/null || true

if [[ ! -f "${MONERO_ENV_FILE}" ]]; then
	if [[ -z "${MONERO_NETWORK}" ]]; then
		MONERO_NETWORK="mainnet"
	fi
	
	if [[ -z ${MONERO_RPC_USER+x} ]] || [[ -z ${MONERO_RPC_PASS+x} ]] || [[ -z ${MONERO_RPC_AUTH+x} ]]; then
		MONERO_RPC_USER="umbrel"
		MONERO_RPC_DETAILS=$("${EXPORTS_APP_DIR}/scripts/rpcauth.py" "${MONERO_RPC_USER}")
		MONERO_RPC_PASS=$(echo "$MONERO_RPC_DETAILS" | tail -1)
		MONERO_RPC_AUTH=$(echo "$MONERO_RPC_DETAILS" | head -2 | tail -1 | sed -e "s/^rpc-login=//")
	fi

	echo "export APP_MONERO_NETWORK='${MONERO_NETWORK}'"		>  "${MONERO_ENV_FILE}"
	echo "export APP_MONERO_RPC_USER='${MONERO_RPC_USER}'"	>> "${MONERO_ENV_FILE}"
	echo "export APP_MONERO_RPC_PASS='${MONERO_RPC_PASS}'"	>> "${MONERO_ENV_FILE}"
	echo "export APP_MONERO_RPC_AUTH='${MONERO_RPC_AUTH}'"	>> "${MONERO_ENV_FILE}"
fi

. "${MONERO_ENV_FILE}"

# Make sure we don't persist the original value in .env if we have a more recent
# value from the app config
{
	if [[ ! -z ${MONERO_NETWORK+x} ]] && [[ "${MONERO_NETWORK}" ]] && [[ "${APP_MONERO_NETWORK}" ]]
	then
		APP_MONERO_NETWORK="${MONERO_NETWORK}"
	fi
} > /dev/null || true

if [[ "${APP_MONERO_NETWORK}" == "mainnet" ]]; then
	MONERO_CHAIN="main"
elif [[ "${APP_MONERO_NETWORK}" == "testnet" ]]; then
	MONERO_CHAIN="test"
	# export APP_BITCOIN_RPC_PORT="18332"
	# export APP_BITCOIN_P2P_PORT="18333"
	# export APP_BITCOIN_TOR_PORT="18334"
elif [[ "${APP_MONERO_NETWORK}" == "stagenet" ]]; then
	MONERO_CHAIN="stage"
	# export APP_BITCOIN_RPC_PORT="38332"
	# export APP_BITCOIN_P2P_PORT="38333"
	# export APP_BITCOIN_TOR_PORT="38334"
else
	echo "Warning (${EXPORTS_APP_ID}): Monero Network '${APP_MONERO_NETWORK}' is not supported"
fi

export MONERO_DEFAULT_NETWORK="${MONERO_CHAIN}"

BIN_ARGS=()
# Commenting out options that are replaced by generated config file. We should migrate all these over in a future update.
# BIN_ARGS+=( "-chain=${BITCOIN_CHAIN}" )
# BIN_ARGS+=( "-proxy=${TOR_PROXY_IP}:${TOR_PROXY_PORT}" )
# BIN_ARGS+=( "-listen" )
# BIN_ARGS+=( "-bind=0.0.0.0:${APP_BITCOIN_TOR_PORT}=onion" )
# BIN_ARGS+=( "-bind=${APP_BITCOIN_NODE_IP}" )
# BIN_ARGS+=( "-port=${APP_BITCOIN_P2P_PORT}" )
# BIN_ARGS+=( "-rpcport=${APP_BITCOIN_RPC_PORT}" )
BIN_ARGS+=( "-port=18080" )
BIN_ARGS+=( "-rpcport=18081" )
BIN_ARGS+=( "--rpc-bind-ip=${APP_MONERO_NODE_IP}" )
BIN_ARGS+=( "--rpc-bind-ip=127.0.0.1" )
BIN_ARGS+=( "--rpc-bind-ip=${NETWORK_IP}/16" )
BIN_ARGS+=( "--rpc-bind-ip=127.0.0.1" )
BIN_ARGS+=( "--rpc-login=\"${APP_MONERO_RPC_AUTH}\"" )


export APP_MONERO_COMMAND=$(IFS=" "; echo "${BIN_ARGS[@]}")

# echo "${APP_MONERO_COMMAND}"

rpc_hidden_service_file="${EXPORTS_TOR_DATA_DIR}/app-${EXPORTS_APP_ID}-rpc/hostname"
p2p_hidden_service_file="${EXPORTS_TOR_DATA_DIR}/app-${EXPORTS_APP_ID}-p2p/hostname"
export APP_MONERO_RPC_HIDDEN_SERVICE="$(cat "${rpc_hidden_service_file}" 2>/dev/null || echo "notyetset.onion")"
export APP_MONERO_P2P_HIDDEN_SERVICE="$(cat "${p2p_hidden_service_file}" 2>/dev/null || echo "notyetset.onion")"

{
	# Migrate settings for app updates differently to fresh installs
	MONERO_INSTALL_EXISTS="false"
	MONERO_DATA_DIR="${EXPORTS_APP_DIR}/data/monero"
	if [[ -d "${MONERO_DATA_DIR}/blocks" ]] || [[ -d "${MONERO_DATA_DIR}/testnet3/blocks" ]] || [[ -d "${MONERO_DATA_DIR}/regtest/blocks" ]]
	then
	MONERO_INSTALL_EXISTS="true"
	fi

	APP_CONFIG_EXISTS="false"
	if [[ -f "${EXPORTS_APP_DIR}/data/app/monero-config.json" ]]
	then
	APP_CONFIG_EXISTS="true"
	fi

	if [[ "${MONERO_INSTALL_EXISTS}" = "true" ]] && [[ "${APP_CONFIG_EXISTS}" = "false" ]]
	then
		# This app is not a fresh install, it's being updated, so preserve existing clearnet over Tor setting
		export MONERO_INITIALIZE_WITH_CLEARNET_OVER_TOR="true"
	fi
} || true