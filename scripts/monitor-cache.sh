#!/bin/bash

# Redis Cache Monitoring and Purging Script
# This script demonstrates real-time cache monitoring and automatic purging

set -e

REDIS_HOST="${REDIS_HOST:-localhost}"
REDIS_PORT="${REDIS_PORT:-6379}"
REDIS_URL="redis://${REDIS_HOST}:${REDIS_PORT}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_debug() {
    echo -e "${BLUE}[DEBUG]${NC} $1"
}

# Function to check if Redis is available
check_redis() {
    if ! redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" ping > /dev/null 2>&1; then
        log_error "Redis server is not available at $REDIS_HOST:$REDIS_PORT"
        log_info "Please ensure Redis is running with: docker run -d -p 6379:6379 redis/redis-stack:latest"
        exit 1
    fi
    log_info "Redis server is available at $REDIS_HOST:$REDIS_PORT"
}

# Function to get Redis memory usage
get_memory_usage() {
    local used_memory=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" info memory | grep "used_memory_human:" | cut -d: -f2 | tr -d '\r')
    local max_memory=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" config get maxmemory | tail -n1)

    echo "Memory Usage: $used_memory"
    if [ "$max_memory" != "0" ]; then
        echo "Max Memory: $(numfmt --to=iec $max_memory)"
    else
        echo "Max Memory: No limit set"
    fi
}

# Function to get key count by pattern
get_key_stats() {
    local total_keys=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" dbsize)
    local cache_keys=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" eval "return #redis.call('keys', 'cache:*')" 0 2>/dev/null || echo "0")
    local session_keys=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" eval "return #redis.call('keys', 'session:*')" 0 2>/dev/null || echo "0")
    local temp_keys=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" eval "return #redis.call('keys', '*temp*')" 0 2>/dev/null || echo "0")

    echo "Total Keys: $total_keys"
    echo "Cache Keys: $cache_keys"
    echo "Session Keys: $session_keys"
    echo "Temporary Keys: $temp_keys"
}

# Function to show keys with TTL information
show_expiring_keys() {
    local threshold=${1:-60}
    log_info "Keys expiring in next $threshold seconds:"

    redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" eval "
        local keys = redis.call('keys', '*')
        local expiring = {}
        for i=1,#keys do
            local ttl = redis.call('ttl', keys[i])
            if ttl > 0 and ttl <= $threshold then
                table.insert(expiring, keys[i] .. ' (TTL: ' .. ttl .. 's)')
            end
        end
        return expiring
    " 0 | while read -r line; do
        if [ -n "$line" ]; then
            echo "  - $line"
        fi
    done
}

# Function to demonstrate cache creation and expiration
demo_cache_expiration() {
    log_info "Creating demo cache entries with different TTL values..."

    # Create test data with various TTLs
    redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" setex "cache:demo:short" 10 "{\"data\":\"short-lived\",\"created\":\"$(date)\"}"
    redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" setex "cache:demo:medium" 30 "{\"data\":\"medium-lived\",\"created\":\"$(date)\"}"
    redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" setex "cache:demo:long" 60 "{\"data\":\"long-lived\",\"created\":\"$(date)\"}"
    redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" set "cache:demo:permanent" "{\"data\":\"no-expiration\",\"created\":\"$(date)\"}"

    # Create temporary data
    redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" setex "temp:demo:data1" 15 "{\"temp\":\"data1\"}"
    redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" setex "temp:demo:data2" 25 "{\"temp\":\"data2\"}"

    # Create session data
    redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" setex "session:user123" 45 "{\"userId\":123,\"role\":\"admin\"}"

    log_info "Demo cache entries created!"
}

# Function to manually purge expired and temporary keys
manual_purge() {
    log_info "Starting manual cache purge..."

    # Count before purge
    local before_count=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" dbsize)

    # Delete all temporary keys
    local temp_deleted=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" eval "
        local keys = redis.call('keys', 'temp:*')
        if #keys > 0 then
            return redis.call('del', unpack(keys))
        else
            return 0
        end
    " 0)

    # Delete keys with no TTL that match cleanup patterns (but keep permanent demo)
    local cleanup_deleted=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" eval "
        local keys = redis.call('keys', 'cache:api:*')
        local deleted = 0
        for i=1,#keys do
            local ttl = redis.call('ttl', keys[i])
            if ttl == -1 then
                redis.call('del', keys[i])
                deleted = deleted + 1
            end
        end
        return deleted
    " 0)

    local after_count=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" dbsize)
    local total_deleted=$((temp_deleted + cleanup_deleted))

    log_info "Purge completed:"
    log_info "  - Temporary keys deleted: $temp_deleted"
    log_info "  - Cleanup keys deleted: $cleanup_deleted"
    log_info "  - Total keys deleted: $total_deleted"
    log_info "  - Keys before: $before_count, after: $after_count"
}

# Function to configure Redis memory management
configure_memory_policy() {
    local max_memory=${1:-"64mb"}
    local policy=${2:-"allkeys-lru"}

    log_info "Configuring Redis memory management..."
    log_info "  - Max Memory: $max_memory"
    log_info "  - Eviction Policy: $policy"

    redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" config set maxmemory "$max_memory"
    redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" config set maxmemory-policy "$policy"
    redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" config set hz 100  # Increase key expiration frequency

    # Verify configuration
    local current_max=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" config get maxmemory | tail -n1)
    local current_policy=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" config get maxmemory-policy | tail -n1)

    log_info "Configuration applied:"
    log_info "  - Max Memory: $(numfmt --to=iec $current_max)"
    log_info "  - Policy: $current_policy"
}

# Function to monitor cache in real-time
monitor_realtime() {
    local duration=${1:-30}
    local interval=${2:-2}

    log_info "Starting real-time cache monitoring for $duration seconds..."
    log_info "Press Ctrl+C to stop monitoring early"

    local start_time=$(date +%s)

    while true; do
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))

        if [ $elapsed -ge $duration ]; then
            break
        fi

        clear
        echo -e "${GREEN}=== Redis Cache Monitor ===${NC} (${elapsed}s/${duration}s)"
        echo

        echo -e "${BLUE}Memory Information:${NC}"
        get_memory_usage
        echo

        echo -e "${BLUE}Key Statistics:${NC}"
        get_key_stats
        echo

        echo -e "${BLUE}Expiring Keys (next 30s):${NC}"
        show_expiring_keys 30
        echo

        echo -e "${YELLOW}Next update in ${interval}s... (Ctrl+C to stop)${NC}"
        sleep $interval
    done

    log_info "Monitoring completed"
}

# Function to run automated purging test
test_auto_purging() {
    log_info "Testing automatic cache purging behavior..."

    # Create test data
    demo_cache_expiration

    log_info "Initial state:"
    get_key_stats
    echo

    log_info "Waiting for keys to expire naturally..."

    # Monitor for 70 seconds to see natural expiration
    for i in {1..14}; do
        sleep 5
        local remaining=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" eval "
            local keys = redis.call('keys', 'cache:demo:*')
            local active = 0
            for i=1,#keys do
                local ttl = redis.call('ttl', keys[i])
                if ttl > 0 or ttl == -1 then
                    active = active + 1
                end
            end
            return active
        " 0)

        echo "Time: ${i}x5s, Active demo keys: $remaining"

        if [ "$remaining" -eq "1" ]; then  # Only permanent key should remain
            log_info "All TTL keys have expired naturally!"
            break
        fi
    done

    log_info "Final state:"
    get_key_stats

    # Clean up remaining demo data
    redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" del "cache:demo:permanent" > /dev/null 2>&1 || true
}

# Main function
main() {
    echo -e "${GREEN}=== Redis Cache Auto-Purging Demonstration ===${NC}"
    echo

    case "${1:-demo}" in
        "check")
            check_redis
            ;;
        "stats")
            check_redis
            echo -e "${BLUE}Memory Information:${NC}"
            get_memory_usage
            echo
            echo -e "${BLUE}Key Statistics:${NC}"
            get_key_stats
            echo
            show_expiring_keys
            ;;
        "demo")
            check_redis
            demo_cache_expiration
            echo
            log_info "Demo data created. Use './monitor-cache.sh stats' to view or './monitor-cache.sh monitor' to watch real-time"
            ;;
        "purge")
            check_redis
            manual_purge
            ;;
        "configure")
            check_redis
            configure_memory_policy "${2:-64mb}" "${3:-allkeys-lru}"
            ;;
        "monitor")
            check_redis
            monitor_realtime "${2:-60}" "${3:-3}"
            ;;
        "test")
            check_redis
            test_auto_purging
            ;;
        "help"|*)
            echo "Usage: $0 [command] [options]"
            echo
            echo "Commands:"
            echo "  check                              - Check Redis connectivity"
            echo "  stats                              - Show current cache statistics"
            echo "  demo                               - Create demo cache entries with TTL"
            echo "  purge                              - Manually purge temporary and expired keys"
            echo "  configure [memory] [policy]        - Configure memory management (default: 64mb allkeys-lru)"
            echo "  monitor [duration] [interval]      - Real-time monitoring (default: 60s, 3s interval)"
            echo "  test                               - Run automatic purging test"
            echo "  help                               - Show this help"
            echo
            echo "Examples:"
            echo "  $0 demo                            # Create test data"
            echo "  $0 monitor 120 2                  # Monitor for 2 minutes, update every 2s"
            echo "  $0 configure 128mb volatile-lru    # Set memory limit and policy"
            echo "  $0 test                            # Full auto-purging demonstration"
            ;;
    esac
}

# Run main function with all arguments
main "$@"
