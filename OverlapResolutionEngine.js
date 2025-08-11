/**
 * OverlapResolutionEngine - Handles conflicts when customers meet multiple bucket criteria
 * 
 * This class provides comprehensive overlap detection, match scoring, and resolution
 * capabilities for customer bucket assignments in the concrete analyzer system.
 * 
 * @class OverlapResolutionEngine
 * @version 1.0.0
 * @author Concrete Analyzer Team
 */
class OverlapResolutionEngine {
    /**
     * Creates an instance of OverlapResolutionEngine
     * 
     * @param {Object} options - Configuration options
     * @param {Object} options.weights - Scoring weights for match calculation
     * @param {number} options.weights.volume - Volume match weight (default: 0.35)
     * @param {number} options.weights.price - Price match weight (default: 0.30)
     * @param {number} options.weights.margin - Margin match weight (default: 0.25)
     * @param {number} options.weights.value - Business value weight (default: 0.10)
     * @param {number} options.matchThreshold - Minimum match score threshold (default: 0.5)
     * @param {number} options.confidenceThreshold - Recommendation confidence threshold (default: 0.7)
     */
    constructor(options = {}) {
        this.weights = {
            volume: 0.35,
            price: 0.30,
            margin: 0.25,
            value: 0.10,
            ...options.weights
        };
        
        this.matchThreshold = options.matchThreshold || 0.5;
        this.confidenceThreshold = options.confidenceThreshold || 0.7;
        
        // Cache for calculated match scores
        this.scoreCache = new Map();
        
        // Resolution decision tracking for machine learning
        this.resolutionHistory = [];
        
        // Performance metrics
        this.performanceMetrics = {
            overlapDetectionTime: 0,
            scoringTime: 0,
            resolutionTime: 0,
            cacheHitRate: 0
        };
        
        this.validateWeights();
    }

    /**
     * Validates that scoring weights sum to 1.0
     * @private
     */
    validateWeights() {
        const sum = Object.values(this.weights).reduce((acc, weight) => acc + weight, 0);
        if (Math.abs(sum - 1.0) > 0.001) {
            throw new Error(`Scoring weights must sum to 1.0, current sum: ${sum.toFixed(3)}`);
        }
    }

    /**
     * Detects customers that meet criteria for multiple buckets
     * 
     * @param {Array} customers - Array of customer analytics objects
     * @param {Array} buckets - Array of customer bucket objects
     * @returns {Promise<Array>} Array of overlap resolution objects
     * 
     * @example
     * const overlaps = await engine.detectOverlaps(customers, buckets);
     * console.log(`Found ${overlaps.length} overlapping customers`);
     */
    async detectOverlaps(customers, buckets) {
        const startTime = performance.now();
        
        try {
            this.validateInputs(customers, buckets);
            
            const overlaps = [];
            
            // Process customers in batches for better performance
            const batchSize = 50;
            for (let i = 0; i < customers.length; i += batchSize) {
                const batch = customers.slice(i, i + batchSize);
                const batchOverlaps = await this.processBatch(batch, buckets);
                overlaps.push(...batchOverlaps);
                
                // Yield control to prevent UI blocking
                if (i % 100 === 0 && i > 0) {
                    await this.sleep(1);
                }
            }
            
            this.performanceMetrics.overlapDetectionTime = performance.now() - startTime;
            
            return this.sortOverlapsByPriority(overlaps);
            
        } catch (error) {
            console.error('Error detecting overlaps:', error);
            throw new Error(`Overlap detection failed: ${error.message}`);
        }
    }

    /**
     * Processes a batch of customers for overlap detection
     * @private
     */
    async processBatch(customers, buckets) {
        const overlaps = [];
        
        for (const customer of customers) {
            // Skip customers already assigned to a bucket
            if (customer.bucketId) continue;
            
            const eligibleBuckets = [];
            
            for (const bucket of buckets) {
                if (this.customerMeetsCriteria(customer, bucket.criteria)) {
                    const matchScore = await this.calculateMatchScores(customer, bucket);
                    
                    if (matchScore >= this.matchThreshold) {
                        eligibleBuckets.push({
                            bucketId: bucket.bucketId,
                            bucketName: bucket.bucketName,
                            matchScore: parseFloat(matchScore.toFixed(3)),
                            criteria: bucket.criteria
                        });
                    }
                }
            }
            
            // Customer has overlap if eligible for multiple buckets
            if (eligibleBuckets.length > 1) {
                overlaps.push(this.createOverlapResolution(customer, eligibleBuckets));
            }
        }
        
        return overlaps;
    }

    /**
     * Checks if customer meets bucket criteria
     * @private
     */
    customerMeetsCriteria(customer, criteria) {
        // Volume criteria
        if (criteria.volumeMin !== null && customer.totalVolume < criteria.volumeMin) {
            return false;
        }
        if (criteria.volumeMax !== null && customer.totalVolume > criteria.volumeMax) {
            return false;
        }
        
        // Price criteria
        if (criteria.priceMin !== null && customer.averageUnitPrice < criteria.priceMin) {
            return false;
        }
        if (criteria.priceMax !== null && customer.averageUnitPrice > criteria.priceMax) {
            return false;
        }
        
        // Profit margin criteria
        if (criteria.profitMarginMin !== null && customer.profitMargin < criteria.profitMarginMin) {
            return false;
        }
        if (criteria.profitMarginMax !== null && customer.profitMargin > criteria.profitMarginMax) {
            return false;
        }
        
        return true;
    }

    /**
     * Calculates match score for customer-bucket pair (0.0-1.0 scale)
     * 
     * @param {Object} customer - Customer analytics object
     * @param {Object} bucket - Customer bucket object
     * @returns {Promise<number>} Match score between 0.0 and 1.0
     * 
     * @example
     * const score = await engine.calculateMatchScores(customer, bucket);
     * console.log(`Match score: ${(score * 100).toFixed(1)}%`);
     */
    async calculateMatchScores(customer, bucket) {
        const startTime = performance.now();
        
        try {
            const cacheKey = `${customer.customerId}-${bucket.bucketId}`;
            
            // Check cache first
            if (this.scoreCache.has(cacheKey)) {
                this.performanceMetrics.cacheHitRate++;
                return this.scoreCache.get(cacheKey);
            }
            
            // Calculate individual component scores
            const volumeScore = this.calculateVolumeScore(customer, bucket.criteria);
            const priceScore = this.calculatePriceScore(customer, bucket.criteria);
            const marginScore = this.calculateMarginScore(customer, bucket.criteria);
            const valueScore = this.calculateBusinessValueScore(customer);
            
            // Weighted composite score
            const compositeScore = (
                volumeScore * this.weights.volume +
                priceScore * this.weights.price +
                marginScore * this.weights.margin +
                valueScore * this.weights.value
            );
            
            // Ensure score is within bounds
            const finalScore = Math.max(0, Math.min(1, compositeScore));
            
            // Cache the result
            this.scoreCache.set(cacheKey, finalScore);
            
            this.performanceMetrics.scoringTime += performance.now() - startTime;
            
            return finalScore;
            
        } catch (error) {
            console.error('Error calculating match score:', error);
            throw new Error(`Match scoring failed: ${error.message}`);
        }
    }

    /**
     * Calculates volume-based match score
     * @private
     */
    calculateVolumeScore(customer, criteria) {
        const volume = customer.totalVolume;
        
        // Perfect match if no volume constraints
        if (criteria.volumeMin === null && criteria.volumeMax === null) {
            return 1.0;
        }
        
        // Calculate fit within range
        let score = 1.0;
        
        if (criteria.volumeMin !== null) {
            if (volume < criteria.volumeMin) {
                return 0; // Hard constraint violation
            }
            // Bonus for exceeding minimum significantly
            const excess = volume - criteria.volumeMin;
            const bonusRange = criteria.volumeMin * 0.5; // 50% bonus range
            score += Math.min(0.2, excess / bonusRange * 0.2);
        }
        
        if (criteria.volumeMax !== null) {
            if (volume > criteria.volumeMax) {
                return 0; // Hard constraint violation
            }
            // Penalize for being too close to maximum
            const proximity = (criteria.volumeMax - volume) / criteria.volumeMax;
            score *= (0.8 + proximity * 0.2); // Minimum 80% score near max
        }
        
        return Math.min(1.0, score);
    }

    /**
     * Calculates price-based match score
     * @private
     */
    calculatePriceScore(customer, criteria) {
        const price = customer.averageUnitPrice;
        
        // Perfect match if no price constraints
        if (criteria.priceMin === null && criteria.priceMax === null) {
            return 1.0;
        }
        
        let score = 1.0;
        
        if (criteria.priceMin !== null) {
            if (price < criteria.priceMin) {
                return 0; // Hard constraint violation
            }
            // Bonus for premium pricing
            const excess = price - criteria.priceMin;
            const bonusRange = criteria.priceMin * 0.3; // 30% bonus range
            score += Math.min(0.15, excess / bonusRange * 0.15);
        }
        
        if (criteria.priceMax !== null) {
            if (price > criteria.priceMax) {
                return 0; // Hard constraint violation
            }
            // Slight penalty for being at the price ceiling
            const proximity = (criteria.priceMax - price) / criteria.priceMax;
            score *= (0.9 + proximity * 0.1);
        }
        
        return Math.min(1.0, score);
    }

    /**
     * Calculates profit margin-based match score
     * @private
     */
    calculateMarginScore(customer, criteria) {
        const margin = customer.profitMargin;
        
        // Perfect match if no margin constraints
        if (criteria.profitMarginMin === null && criteria.profitMarginMax === null) {
            return 1.0;
        }
        
        let score = 1.0;
        
        if (criteria.profitMarginMin !== null) {
            if (margin < criteria.profitMarginMin) {
                return 0; // Hard constraint violation
            }
            // Significant bonus for high margins
            const excess = margin - criteria.profitMarginMin;
            const bonusRange = 20; // 20 percentage points bonus range
            score += Math.min(0.3, excess / bonusRange * 0.3);
        }
        
        if (criteria.profitMarginMax !== null) {
            if (margin > criteria.profitMarginMax) {
                return 0; // Hard constraint violation
            }
            // Minor penalty for being at margin ceiling
            const proximity = (criteria.profitMarginMax - margin) / criteria.profitMarginMax;
            score *= (0.95 + proximity * 0.05);
        }
        
        return Math.min(1.0, score);
    }

    /**
     * Calculates business value score based on revenue potential
     * @private
     */
    calculateBusinessValueScore(customer) {
        // Normalize revenue to 0-1 scale (assuming max revenue of $100,000)
        const maxRevenue = 100000;
        const revenueScore = Math.min(1.0, customer.totalRevenue / maxRevenue);
        
        // Factor in delivery frequency (more deliveries = better customer)
        const frequencyBonus = Math.min(0.2, customer.deliveryCount / 50 * 0.2);
        
        // Recent activity bonus
        const daysSinceLastOrder = this.calculateDaysSince(customer.lastOrderDate);
        const recencyBonus = daysSinceLastOrder <= 30 ? 0.1 : 
                           daysSinceLastOrder <= 90 ? 0.05 : 0;
        
        return Math.min(1.0, revenueScore + frequencyBonus + recencyBonus);
    }

    /**
     * Generates recommendations for best bucket assignment
     * 
     * @param {Array} overlapData - Array of overlap resolution objects
     * @returns {Promise<Array>} Enhanced overlap data with recommendations
     * 
     * @example
     * const recommendations = await engine.generateRecommendations(overlaps);
     * recommendations.forEach(rec => {
     *   console.log(`Recommend ${rec.customerName} → ${rec.recommendedBucket}`);
     * });
     */
    async generateRecommendations(overlapData) {
        const startTime = performance.now();
        
        try {
            const enhancedOverlaps = [];
            
            for (const overlap of overlapData) {
                const enhanced = { ...overlap };
                
                // Sort buckets by match score
                enhanced.eligibleBuckets.sort((a, b) => b.matchScore - a.matchScore);
                
                // Select best match
                const bestMatch = enhanced.eligibleBuckets[0];
                enhanced.recommendedBucket = bestMatch.bucketId;
                enhanced.recommendedBucketName = bestMatch.bucketName;
                
                // Calculate confidence score
                const scores = enhanced.eligibleBuckets.map(b => b.matchScore);
                const confidence = this.calculateRecommendationConfidence(scores);
                enhanced.confidence = parseFloat(confidence.toFixed(3));
                
                // Generate detailed reasoning
                enhanced.reasoning = this.generateRecommendationReasoning(
                    overlap.customer, 
                    bestMatch, 
                    enhanced.eligibleBuckets
                );
                
                // Add alternative suggestions if confidence is low
                if (confidence < this.confidenceThreshold) {
                    enhanced.alternatives = enhanced.eligibleBuckets.slice(0, 3)
                        .map(bucket => ({
                            bucketId: bucket.bucketId,
                            bucketName: bucket.bucketName,
                            matchScore: bucket.matchScore,
                            reason: this.generateAlternativeReason(overlap.customer, bucket)
                        }));
                }
                
                enhancedOverlaps.push(enhanced);
            }
            
            this.performanceMetrics.resolutionTime = performance.now() - startTime;
            
            return enhancedOverlaps;
            
        } catch (error) {
            console.error('Error generating recommendations:', error);
            throw new Error(`Recommendation generation failed: ${error.message}`);
        }
    }

    /**
     * Calculates confidence score for recommendations
     * @private
     */
    calculateRecommendationConfidence(scores) {
        if (scores.length < 2) return 1.0;
        
        const topScore = scores[0];
        const secondScore = scores[1];
        
        // Higher confidence when there's a clear winner
        const scoreDifference = topScore - secondScore;
        const baseConfidence = Math.min(1.0, topScore);
        const differenceBonus = Math.min(0.3, scoreDifference * 2);
        
        return Math.min(1.0, baseConfidence + differenceBonus);
    }

    /**
     * Generates human-readable reasoning for recommendations
     * @private
     */
    generateRecommendationReasoning(customer, bestMatch, allBuckets) {
        const reasons = [];
        
        // Primary strength identification
        if (customer.totalVolume >= 500) {
            reasons.push(`High volume customer (${customer.totalVolume.toFixed(0)} yards)`);
        }
        
        if (customer.averageUnitPrice >= 120) {
            reasons.push(`Premium pricing ($${customer.averageUnitPrice.toFixed(2)}/yard)`);
        }
        
        if (customer.profitMargin >= 25) {
            reasons.push(`Excellent margins (${customer.profitMargin.toFixed(1)}%)`);
        }
        
        if (customer.totalRevenue >= 50000) {
            reasons.push(`High-value customer ($${customer.totalRevenue.toLocaleString()})`);
        }
        
        // Match quality
        const matchPercent = (bestMatch.matchScore * 100).toFixed(0);
        reasons.push(`${matchPercent}% match with ${bestMatch.bucketName}`);
        
        // Comparison with alternatives
        if (allBuckets.length > 1) {
            const scoreDiff = (bestMatch.matchScore - allBuckets[1].matchScore) * 100;
            if (scoreDiff >= 10) {
                reasons.push(`Significantly better than alternatives (+${scoreDiff.toFixed(0)}%)`);
            }
        }
        
        return reasons.join('; ');
    }

    /**
     * Presents conflict resolution data for UI components
     * 
     * @param {Array} overlaps - Array of overlap resolution objects
     * @returns {Object} Structured data for conflict resolution UI
     * 
     * @example
     * const uiData = engine.presentConflictResolution(overlaps);
     * // Render UI components with uiData.conflicts, uiData.summary, etc.
     */
    presentConflictResolution(overlaps) {
        try {
            const summary = this.generateConflictSummary(overlaps);
            const conflicts = this.formatConflictsForUI(overlaps);
            const recommendations = this.generateBulkRecommendations(overlaps);
            
            return {
                summary,
                conflicts,
                recommendations,
                metadata: {
                    totalConflicts: overlaps.length,
                    highConfidenceCount: overlaps.filter(o => o.confidence >= this.confidenceThreshold).length,
                    averageConfidence: this.calculateAverageConfidence(overlaps),
                    resolutionStrategies: this.getAvailableStrategies()
                }
            };
            
        } catch (error) {
            console.error('Error presenting conflict resolution:', error);
            throw new Error(`Conflict presentation failed: ${error.message}`);
        }
    }

    /**
     * Automatically resolves overlaps using specified strategy
     * 
     * @param {Array} overlaps - Array of overlap resolution objects
     * @param {string} strategy - Resolution strategy ('HIGHEST_VALUE', 'BEST_FIT', etc.)
     * @returns {Promise<Array>} Array of resolution decisions
     * 
     * @example
     * const decisions = await engine.autoResolveByPriority(overlaps, 'BEST_FIT');
     * decisions.forEach(decision => {
     *   console.log(`${decision.customerName} assigned to ${decision.assignedBucket}`);
     * });
     */
    async autoResolveByPriority(overlaps, strategy) {
        const startTime = performance.now();
        
        try {
            this.validateStrategy(strategy);
            
            const decisions = [];
            
            for (const overlap of overlaps) {
                const decision = await this.applyResolutionStrategy(overlap, strategy);
                decisions.push(decision);
                
                // Track decision for learning
                this.trackResolutionDecisions([decision]);
            }
            
            this.performanceMetrics.resolutionTime += performance.now() - startTime;
            
            return this.validateResolutionDecisions(decisions);
            
        } catch (error) {
            console.error('Error in auto-resolution:', error);
            throw new Error(`Auto-resolution failed: ${error.message}`);
        }
    }

    /**
     * Applies specific resolution strategy to an overlap
     * @private
     */
    async applyResolutionStrategy(overlap, strategy) {
        const customer = overlap.customer;
        const buckets = overlap.eligibleBuckets;
        
        let selectedBucket;
        let reason;
        
        switch (strategy) {
            case 'HIGHEST_VALUE':
                selectedBucket = this.selectByHighestValue(customer, buckets);
                reason = 'Selected based on customer business value';
                break;
                
            case 'BEST_FIT':
                selectedBucket = buckets[0]; // Already sorted by match score
                reason = 'Selected based on highest match score';
                break;
                
            case 'VOLUME_PRIORITY':
                selectedBucket = this.selectByVolumePriority(customer, buckets);
                reason = 'Selected based on volume optimization';
                break;
                
            case 'MARGIN_PRIORITY':
                selectedBucket = this.selectByMarginPriority(customer, buckets);
                reason = 'Selected based on profit margin optimization';
                break;
                
            default:
                throw new Error(`Unknown resolution strategy: ${strategy}`);
        }
        
        return {
            customerId: customer.customerId,
            customerName: customer.customerName,
            assignedBucket: selectedBucket.bucketId,
            assignedBucketName: selectedBucket.bucketName,
            strategy: strategy,
            matchScore: selectedBucket.matchScore,
            reason: reason,
            timestamp: new Date().toISOString(),
            alternatives: buckets.filter(b => b.bucketId !== selectedBucket.bucketId)
                .slice(0, 2) // Top 2 alternatives
        };
    }

    /**
     * Tracks resolution decisions for machine learning improvement
     * 
     * @param {Array} decisions - Array of resolution decision objects
     * @returns {void}
     * 
     * @example
     * engine.trackResolutionDecisions(userDecisions);
     * // Decisions are stored for pattern analysis and improvement
     */
    trackResolutionDecisions(decisions) {
        try {
            for (const decision of decisions) {
                const trackingData = {
                    ...decision,
                    sessionId: this.generateSessionId(),
                    userAgent: navigator.userAgent,
                    timestamp: new Date().toISOString(),
                    performanceMetrics: { ...this.performanceMetrics }
                };
                
                this.resolutionHistory.push(trackingData);
            }
            
            // Limit history size to prevent memory issues
            if (this.resolutionHistory.length > 1000) {
                this.resolutionHistory = this.resolutionHistory.slice(-500);
            }
            
            // Analyze patterns if enough data
            if (this.resolutionHistory.length >= 50) {
                this.analyzeResolutionPatterns();
            }
            
        } catch (error) {
            console.error('Error tracking resolution decisions:', error);
            // Non-critical error - don't throw
        }
    }

    /**
     * Gets performance metrics for monitoring
     * 
     * @returns {Object} Performance metrics object
     */
    getPerformanceMetrics() {
        return {
            ...this.performanceMetrics,
            cacheSize: this.scoreCache.size,
            historySize: this.resolutionHistory.length,
            averageOverlapDetectionTime: this.performanceMetrics.overlapDetectionTime,
            averageScoringTime: this.performanceMetrics.scoringTime,
            averageResolutionTime: this.performanceMetrics.resolutionTime
        };
    }

    /**
     * Clears internal caches and resets metrics
     * 
     * @returns {void}
     */
    clearCache() {
        this.scoreCache.clear();
        this.performanceMetrics = {
            overlapDetectionTime: 0,
            scoringTime: 0,
            resolutionTime: 0,
            cacheHitRate: 0
        };
    }

    // ========== Private Helper Methods ==========

    /**
     * Creates overlap resolution object
     * @private
     */
    createOverlapResolution(customer, eligibleBuckets) {
        // Sort buckets by match score (highest first)
        eligibleBuckets.sort((a, b) => b.matchScore - a.matchScore);
        
        const conflictReasons = [];
        
        // Generate conflict reason
        if (eligibleBuckets.length === 2) {
            conflictReasons.push(`Customer meets criteria for both ${eligibleBuckets[0].bucketName} and ${eligibleBuckets[1].bucketName}`);
        } else {
            conflictReasons.push(`Customer meets criteria for ${eligibleBuckets.length} buckets: ${eligibleBuckets.map(b => b.bucketName).join(', ')}`);
        }
        
        return {
            customerId: customer.customerId,
            customerName: customer.customerName,
            customer: customer,
            eligibleBuckets: eligibleBuckets,
            recommendedBucket: eligibleBuckets[0].bucketId,
            recommendedBucketName: eligibleBuckets[0].bucketName,
            conflictReason: conflictReasons.join('; '),
            priority: this.calculateOverlapPriority(customer, eligibleBuckets)
        };
    }

    /**
     * Calculates priority for overlap resolution
     * @private
     */
    calculateOverlapPriority(customer, buckets) {
        // Higher revenue customers get higher priority
        const revenueScore = Math.min(1.0, customer.totalRevenue / 100000);
        
        // More buckets = higher complexity = higher priority
        const complexityScore = Math.min(1.0, buckets.length / 5);
        
        // Close match scores = harder decision = higher priority
        const scoreDifference = buckets.length > 1 ? 
            buckets[0].matchScore - buckets[1].matchScore : 1.0;
        const difficultyScore = 1.0 - Math.min(1.0, scoreDifference);
        
        return (revenueScore * 0.4 + complexityScore * 0.3 + difficultyScore * 0.3);
    }

    /**
     * Sorts overlaps by priority (highest first)
     * @private
     */
    sortOverlapsByPriority(overlaps) {
        return overlaps.sort((a, b) => b.priority - a.priority);
    }

    /**
     * Validates input parameters
     * @private
     */
    validateInputs(customers, buckets) {
        if (!Array.isArray(customers)) {
            throw new Error('Customers must be an array');
        }
        
        if (!Array.isArray(buckets)) {
            throw new Error('Buckets must be an array');
        }
        
        if (customers.length === 0) {
            throw new Error('Customer array cannot be empty');
        }
        
        if (buckets.length === 0) {
            throw new Error('Bucket array cannot be empty');
        }
        
        // Validate customer structure
        for (const customer of customers) {
            this.validateCustomerStructure(customer);
        }
        
        // Validate bucket structure
        for (const bucket of buckets) {
            this.validateBucketStructure(bucket);
        }
    }

    /**
     * Validates customer object structure
     * @private
     */
    validateCustomerStructure(customer) {
        const required = ['customerId', 'customerName', 'totalVolume', 'averageUnitPrice', 'profitMargin', 'totalRevenue'];
        
        for (const field of required) {
            if (customer[field] === undefined || customer[field] === null) {
                throw new Error(`Customer missing required field: ${field}`);
            }
        }
        
        if (typeof customer.totalVolume !== 'number' || customer.totalVolume < 0) {
            throw new Error('Customer totalVolume must be a positive number');
        }
        
        if (typeof customer.averageUnitPrice !== 'number' || customer.averageUnitPrice <= 0) {
            throw new Error('Customer averageUnitPrice must be a positive number');
        }
        
        if (typeof customer.profitMargin !== 'number') {
            throw new Error('Customer profitMargin must be a number');
        }
    }

    /**
     * Validates bucket object structure
     * @private
     */
    validateBucketStructure(bucket) {
        const required = ['bucketId', 'bucketName', 'criteria'];
        
        for (const field of required) {
            if (bucket[field] === undefined || bucket[field] === null) {
                throw new Error(`Bucket missing required field: ${field}`);
            }
        }
        
        const criteria = bucket.criteria;
        
        // Validate criteria ranges
        if (criteria.volumeMin !== null && criteria.volumeMax !== null) {
            if (criteria.volumeMin > criteria.volumeMax) {
                throw new Error('Bucket volume minimum cannot exceed maximum');
            }
        }
        
        if (criteria.priceMin !== null && criteria.priceMax !== null) {
            if (criteria.priceMin > criteria.priceMax) {
                throw new Error('Bucket price minimum cannot exceed maximum');
            }
        }
        
        if (criteria.profitMarginMin !== null && criteria.profitMarginMax !== null) {
            if (criteria.profitMarginMin > criteria.profitMarginMax) {
                throw new Error('Bucket profit margin minimum cannot exceed maximum');
            }
        }
    }

    /**
     * Strategy-specific selection methods
     * @private
     */
    selectByHighestValue(customer, buckets) {
        // Prioritize buckets that maximize business value
        const valueScores = buckets.map(bucket => {
            const revenueWeight = customer.totalRevenue / 100000; // Normalize to 0-1
            const volumeWeight = customer.totalVolume / 1000; // Normalize to 0-1
            const combinedValue = (bucket.matchScore * 0.6) + (revenueWeight * 0.25) + (volumeWeight * 0.15);
            return { bucket, value: combinedValue };
        });
        
        valueScores.sort((a, b) => b.value - a.value);
        return valueScores[0].bucket;
    }

    selectByVolumePriority(customer, buckets) {
        // Prioritize high-volume bucket assignments
        return buckets.reduce((best, current) => {
            const bestVolumeScore = this.calculateVolumeScore(customer, best.criteria);
            const currentVolumeScore = this.calculateVolumeScore(customer, current.criteria);
            return currentVolumeScore > bestVolumeScore ? current : best;
        });
    }

    selectByMarginPriority(customer, buckets) {
        // Prioritize high-margin bucket assignments
        return buckets.reduce((best, current) => {
            const bestMarginScore = this.calculateMarginScore(customer, best.criteria);
            const currentMarginScore = this.calculateMarginScore(customer, current.criteria);
            return currentMarginScore > bestMarginScore ? current : best;
        });
    }

    /**
     * Utility methods
     * @private
     */
    calculateDaysSince(dateString) {
        const date = new Date(dateString);
        const now = new Date();
        return Math.floor((now - date) / (1000 * 60 * 60 * 24));
    }

    generateSessionId() {
        return 'session_' + Date.now() + '_' + Math.random().toString(36).substr(2, 9);
    }

    sleep(ms) {
        return new Promise(resolve => setTimeout(resolve, ms));
    }

    validateStrategy(strategy) {
        const validStrategies = ['HIGHEST_VALUE', 'BEST_FIT', 'VOLUME_PRIORITY', 'MARGIN_PRIORITY', 'MANUAL'];
        if (!validStrategies.includes(strategy)) {
            throw new Error(`Invalid strategy: ${strategy}. Valid strategies: ${validStrategies.join(', ')}`);
        }
    }

    generateConflictSummary(overlaps) {
        const totalConflicts = overlaps.length;
        const avgBucketsPerConflict = overlaps.reduce((sum, o) => sum + o.eligibleBuckets.length, 0) / totalConflicts;
        const highValueConflicts = overlaps.filter(o => o.customer.totalRevenue >= 50000).length;
        
        return {
            totalConflicts,
            avgBucketsPerConflict: parseFloat(avgBucketsPerConflict.toFixed(1)),
            highValueConflicts,
            percentageHighValue: parseFloat((highValueConflicts / totalConflicts * 100).toFixed(1))
        };
    }

    formatConflictsForUI(overlaps) {
        return overlaps.map(overlap => ({
            ...overlap,
            displayName: overlap.customerName,
            displayValue: `$${overlap.customer.totalRevenue.toLocaleString()}`,
            displayVolume: `${overlap.customer.totalVolume.toFixed(0)} yards`,
            displayPrice: `$${overlap.customer.averageUnitPrice.toFixed(2)}/yard`,
            displayMargin: `${overlap.customer.profitMargin.toFixed(1)}%`,
            bucketOptions: overlap.eligibleBuckets.map(bucket => ({
                ...bucket,
                displayScore: `${(bucket.matchScore * 100).toFixed(0)}%`,
                isRecommended: bucket.bucketId === overlap.recommendedBucket
            }))
        }));
    }

    generateBulkRecommendations(overlaps) {
        const strategies = [
            {
                name: 'BEST_FIT',
                description: 'Assign customers to their highest-scoring bucket',
                estimatedTime: '< 1 minute',
                confidence: 'High'
            },
            {
                name: 'HIGHEST_VALUE',
                description: 'Prioritize high-revenue customer placements',
                estimatedTime: '< 1 minute',
                confidence: 'Medium-High'
            },
            {
                name: 'VOLUME_PRIORITY',
                description: 'Optimize for volume-based bucket assignments',
                estimatedTime: '< 1 minute',
                confidence: 'Medium'
            }
        ];
        
        return strategies;
    }

    calculateAverageConfidence(overlaps) {
        if (overlaps.length === 0) return 0;
        const total = overlaps.reduce((sum, o) => sum + (o.confidence || 0.5), 0);
        return parseFloat((total / overlaps.length).toFixed(3));
    }

    getAvailableStrategies() {
        return [
            { id: 'BEST_FIT', name: 'Best Match Score', description: 'Use highest composite match score' },
            { id: 'HIGHEST_VALUE', name: 'Business Value', description: 'Prioritize high-revenue customers' },
            { id: 'VOLUME_PRIORITY', name: 'Volume Focus', description: 'Optimize volume-based assignments' },
            { id: 'MARGIN_PRIORITY', name: 'Margin Focus', description: 'Optimize profit margin assignments' },
            { id: 'MANUAL', name: 'Manual Review', description: 'Review each conflict individually' }
        ];
    }

    generateAlternativeReason(customer, bucket) {
        if (bucket.matchScore >= 0.8) {
            return 'Excellent alternative with strong match score';
        } else if (bucket.matchScore >= 0.6) {
            return 'Good alternative worth considering';
        } else {
            return 'Lower match but may have strategic value';
        }
    }

    validateResolutionDecisions(decisions) {
        // Check for duplicate assignments
        const assignedBuckets = new Map();
        
        for (const decision of decisions) {
            const customerId = decision.customerId;
            const bucketId = decision.assignedBucket;
            
            if (assignedBuckets.has(customerId)) {
                throw new Error(`Customer ${customerId} assigned to multiple buckets`);
            }
            
            assignedBuckets.set(customerId, bucketId);
        }
        
        return decisions;
    }

    analyzeResolutionPatterns() {
        // Simple pattern analysis for future enhancement
        const patterns = {
            mostUsedStrategy: this.findMostUsedStrategy(),
            averageConfidence: this.calculateHistoricalConfidence(),
            resolutionTime: this.calculateAverageResolutionTime()
        };
        
        console.log('Resolution patterns:', patterns);
        return patterns;
    }

    findMostUsedStrategy() {
        const strategyCounts = {};
        
        for (const decision of this.resolutionHistory) {
            const strategy = decision.strategy || 'MANUAL';
            strategyCounts[strategy] = (strategyCounts[strategy] || 0) + 1;
        }
        
        return Object.entries(strategyCounts)
            .sort(([,a], [,b]) => b - a)
            .map(([strategy, count]) => ({ strategy, count }))[0];
    }

    calculateHistoricalConfidence() {
        const confidences = this.resolutionHistory
            .map(d => d.confidence || 0.5)
            .filter(c => c > 0);
            
        return confidences.length > 0 ? 
            confidences.reduce((sum, c) => sum + c, 0) / confidences.length : 0.5;
    }

    calculateAverageResolutionTime() {
        const times = this.resolutionHistory
            .map(d => d.performanceMetrics?.resolutionTime || 0)
            .filter(t => t > 0);
            
        return times.length > 0 ? 
            times.reduce((sum, t) => sum + t, 0) / times.length : 0;
    }
}

// Export for use in other modules
if (typeof module !== 'undefined' && module.exports) {
    module.exports = OverlapResolutionEngine;
} else if (typeof window !== 'undefined') {
    window.OverlapResolutionEngine = OverlapResolutionEngine;
}