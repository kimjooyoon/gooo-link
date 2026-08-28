package main

import (
	"crypto/sha256"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

const (
	closed  = "CLOSED"
	unknown = "UNKNOWN"
	refuted = "REFUTED"
)

type countSpec struct {
	Name  string `json:"-"`
	Total int    `json:"total"`
}

type cellSpec struct {
	ID             string   `json:"id"`
	Activity       string   `json:"activity"`
	Proof          string   `json:"proof"`
	IndicatorClass string   `json:"indicator_class"`
	DependsOn      []string `json:"depends_on"`
}

type denominator struct {
	Schema                      string           `json:"schema"`
	Total                       int              `json:"total"`
	MinimumIndependentConsumers int              `json:"minimum_independent_consumers"`
	RequiredEvidencePerConsumer int              `json:"required_evidence_per_consumer"`
	RequiredReportSchema        string           `json:"required_report_schema"`
	RequiredVerificationSchema  string           `json:"required_verification_schema"`
	Proofs                      []namedCountSpec `json:"proofs"`
	IndicatorClasses            []namedCountSpec `json:"indicator_classes"`
	Cells                       []cellSpec       `json:"cells"`
}

type namedCountSpec struct {
	Choice string `json:"choice,omitempty"`
	Class  string `json:"class,omitempty"`
	Total  int    `json:"total"`
}

type assetLock struct {
	Kind   string `json:"kind"`
	Name   string `json:"name"`
	SHA256 string `json:"sha256"`
}

type releaseLock struct {
	ID              string      `json:"id"`
	Role            string      `json:"role"`
	Repository      string      `json:"repository"`
	Tag             string      `json:"tag"`
	TagObjectSHA    string      `json:"tag_object_sha"`
	TargetCommitSHA string      `json:"target_commit_sha"`
	Draft           bool        `json:"draft"`
	Prerelease      bool        `json:"prerelease"`
	Assets          []assetLock `json:"assets"`
}

type releaseLocks struct {
	Schema   string        `json:"schema"`
	Releases []releaseLock `json:"releases"`
}

type releaseObservation struct {
	Schema                 string        `json:"schema"`
	SubjectSHA             string        `json:"subject_sha"`
	SourceRepositoryWrites int           `json:"source_repository_writes"`
	Releases               []releaseLock `json:"releases"`
}

type graphNode struct {
	Kind string `json:"kind"`
	Name string `json:"name"`
}

type graph struct {
	SchemaVersion string      `json:"schema_version"`
	Nodes         []graphNode `json:"nodes"`
}

type closedTotal struct {
	Choice string `json:"choice,omitempty"`
	Class  string `json:"class,omitempty"`
	Closed int    `json:"closed"`
	Total  int    `json:"total"`
}

type generationReport struct {
	Schema     string        `json:"schema"`
	Decision   string        `json:"decision"`
	Summary    reportSummary `json:"summary"`
	Claim      inputClaim    `json:"claim"`
	Proofs     []closedTotal `json:"proofs"`
	Indicators []closedTotal `json:"indicators"`
}

type reportSummary struct {
	Closed            int `json:"closed"`
	DependencyBlocked int `json:"dependency_blocked"`
	DirectMissing     int `json:"direct_missing"`
	Refuted           int `json:"refuted"`
	Total             int `json:"total"`
	Unknown           int `json:"unknown"`
}

type inputClaim struct {
	State string `json:"state"`
}

type verificationReport struct {
	Schema                string        `json:"schema"`
	Decision              string        `json:"decision"`
	Summary               reportSummary `json:"summary"`
	Claim                 inputClaim    `json:"claim"`
	ManifestIdentityMatch bool          `json:"manifest_identity_match"`
}

type consumerRuntime struct {
	Schema              string `json:"schema"`
	SubjectSHA          string `json:"subject_sha"`
	DeterministicReplay bool   `json:"deterministic_replay"`
	LocalTestsRun       int    `json:"local_tests_run"`
	Repository          struct {
		BeforeDigest string `json:"before_digest"`
		AfterDigest  string `json:"after_digest"`
		Writes       int    `json:"writes"`
	} `json:"repository"`
}

type generatorPin struct {
	Schema    string `json:"schema"`
	Generator struct {
		Repository      string `json:"repository"`
		Tag             string `json:"tag"`
		TagObjectSHA    string `json:"tag_object_sha"`
		TargetCommitSHA string `json:"target_commit_sha"`
		PortableAsset   struct {
			Name   string `json:"name"`
			SHA256 string `json:"sha256"`
		} `json:"portable_asset"`
	} `json:"generator"`
}

type fact struct {
	State         string
	Stage         string
	Step          string
	Reason        string
	UnknownClass  string
	NextOperation string
	Details       []string
}

type cellResult struct {
	ID             string   `json:"id"`
	Activity       string   `json:"activity"`
	Proof          string   `json:"proof"`
	IndicatorClass string   `json:"indicator_class"`
	State          string   `json:"state"`
	Reason         string   `json:"reason"`
	UnknownClass   *string  `json:"unknown_class"`
	BlockedBy      []string `json:"blocked_by"`
}

type outputClaim struct {
	ID            string   `json:"id"`
	State         string   `json:"state"`
	Stage         *string  `json:"stage"`
	Step          *string  `json:"step"`
	Reason        string   `json:"reason"`
	UnknownClass  *string  `json:"unknown_class"`
	NextOperation string   `json:"next_operation"`
	BlockedBy     []string `json:"blocked_by"`
}

type indicator struct {
	ID       string `json:"id"`
	Activity string `json:"activity"`
	Class    string `json:"class"`
	State    string `json:"state"`
	Value    int    `json:"value"`
	Total    int    `json:"total"`
	Unit     string `json:"unit"`
}

type ratio struct {
	Observed int `json:"observed"`
	Total    int `json:"total"`
}

type observations struct {
	IndependentConsumers ratio    `json:"independent_consumers"`
	EvidenceAssets       ratio    `json:"evidence_assets"`
	GeneratedCells       ratio    `json:"generated_cells"`
	VerificationCells    ratio    `json:"verification_cells"`
	ConsumerRepositories []string `json:"consumer_repositories"`
	GeneratorTag         string   `json:"generator_tag"`
}

type authority struct {
	Inputs                    string `json:"inputs"`
	MetricBinding             string `json:"metric_binding"`
	GeneratorScope            string `json:"generator_scope"`
	ExecutableCIGeneration    string `json:"executable_ci_generation"`
	SourceRepositoryEditing   string `json:"source_repository_editing"`
	CrossProjectRequiredGates int    `json:"cross_project_required_gates"`
	CurrentBranchInputs       int    `json:"current_branch_inputs"`
	RootReadmeReadiness       string `json:"root_readme_readiness"`
}

type report struct {
	Schema           string        `json:"schema"`
	Decision         string        `json:"decision"`
	SubjectSHA       string        `json:"subject_sha"`
	Summary          reportSummary `json:"summary"`
	Proofs           []closedTotal `json:"proofs"`
	IndicatorClasses []closedTotal `json:"indicator_classes"`
	Cells            []cellResult  `json:"cells"`
	Claim            outputClaim   `json:"claim"`
	Observations     observations  `json:"observations"`
	Indicators       []indicator   `json:"indicators"`
	Authority        authority     `json:"authority"`
}

type evaluator struct {
	denominator denominator
	locks       releaseLocks
	observation releaseObservation
	graph       graph
	root        string
}

func main() {
	if len(os.Args) != 7 {
		fatalf("usage: %s DENOMINATOR LOCKS GRAPH RELEASE_OBSERVATION DOWNLOAD_ROOT OUTPUT", os.Args[0])
	}

	var e evaluator
	readJSON(os.Args[1], &e.denominator)
	readJSON(os.Args[2], &e.locks)
	readJSON(os.Args[3], &e.graph)
	readJSON(os.Args[4], &e.observation)
	e.root = os.Args[5]

	result := e.evaluate()
	data, err := json.MarshalIndent(result, "", "  ")
	if err != nil {
		fatalf("marshal report: %v", err)
	}
	data = append(data, '\n')
	if err := os.WriteFile(os.Args[6], data, 0o644); err != nil {
		fatalf("write report: %v", err)
	}
}

func (e *evaluator) evaluate() report {
	if e.denominator.Total != len(e.denominator.Cells) {
		fatalf("denominator total %d does not equal cell count %d", e.denominator.Total, len(e.denominator.Cells))
	}

	activityCounts := make(map[string]int)
	for _, node := range e.graph.Nodes {
		if node.Kind == "Activity" {
			activityCounts[node.Name]++
		}
	}

	results := make([]cellResult, 0, len(e.denominator.Cells))
	byID := make(map[string]cellResult)
	for _, spec := range e.denominator.Cells {
		direct := e.directFact(spec.ID)
		if activityCounts[spec.Activity] != 1 {
			direct = refutedFact("META_BINDING", "BIND_METRIC_TO_GOOO_ACTIVITY", "META_ACTIVITY_CARDINALITY_INVALID", "RESTORE_EXACTLY_ONE_META_ACTIVITY", fmt.Sprintf("%s=%d", spec.Activity, activityCounts[spec.Activity]))
		}
		resolved, blocked := resolveDependencies(direct, spec.DependsOn, byID)
		cell := cellResult{
			ID:             spec.ID,
			Activity:       spec.Activity,
			Proof:          spec.Proof,
			IndicatorClass: spec.IndicatorClass,
			State:          resolved.State,
			Reason:         resolved.Reason,
			UnknownClass:   nullable(resolved.UnknownClass),
			BlockedBy:      blocked,
		}
		results = append(results, cell)
		byID[cell.ID] = cell
	}

	summary := summarize(results)
	proofs := aggregateProofs(e.denominator.Proofs, results)
	classes := aggregateClasses(e.denominator.IndicatorClasses, results)
	obs := e.observationMetrics()
	claim, decision := selectClaim(results)
	return report{
		Schema:           "gooo/link/generator-consumer-promotion-report/v1",
		Decision:         decision,
		SubjectSHA:       e.observation.SubjectSHA,
		Summary:          summary,
		Proofs:           proofs,
		IndicatorClasses: classes,
		Cells:            results,
		Claim:            claim,
		Observations:     obs,
		Indicators:       makeIndicators(summary, obs, e.totalRepositoryWrites(), e.totalLocalTests()),
		Authority: authority{
			Inputs:                    "PINNED_IMMUTABLE_RELEASE_ASSETS",
			MetricBinding:             "EXACTLY_ONE_GOOO_ACTIVITY_PER_CELL",
			GeneratorScope:            "DECLARATIVE_EVIDENCE_PROJECT_GENERATION",
			ExecutableCIGeneration:    "NOT_CLAIMED",
			SourceRepositoryEditing:   "FORBIDDEN",
			CrossProjectRequiredGates: 0,
			CurrentBranchInputs:       0,
			RootReadmeReadiness:       "EXCLUDED",
		},
	}
}

func (e *evaluator) directFact(id string) fact {
	switch id {
	case "core-release-identity":
		return e.releaseFact("core")
	case "generator-release-identity":
		return e.releaseFact("generator")
	case "local-consumer-release":
		return e.releaseFact("local-ledger")
	case "design-consumer-release":
		return e.releaseFact("design-evidence")
	case "independent-consumer-repositories":
		return e.independenceFact()
	case "shared-generator-identity":
		return e.sharedGeneratorFact()
	case "v2-report-contract":
		return e.reportContractFact()
	case "generation-closure":
		return e.generationClosureFact()
	case "generated-file-verification":
		return e.verificationFact()
	case "deterministic-read-only-runtime":
		return e.runtimeFact()
	case "public-checksum-bundle":
		return e.checksumFact()
	case "promotion-decision":
		if len(e.consumerLocks()) < e.denominator.MinimumIndependentConsumers {
			return unknownFact("PROMOTION", "COUNT_INDEPENDENT_GENERATOR_CONSUMERS", "GENERATOR_CONSUMER_THRESHOLD_NOT_REACHED", "DIRECT_MISSING", "PUBLISH_ANOTHER_INDEPENDENT_CONSUMER")
		}
		return closedFact("GENERATOR_PROMOTION_THRESHOLD_REACHED")
	default:
		return refutedFact("DENOMINATOR", "SELECT_CELL", "UNKNOWN_DENOMINATOR_CELL", "REPAIR_DENOMINATOR", id)
	}
}

func (e *evaluator) releaseFact(id string) fact {
	expected, ok := findRelease(e.locks.Releases, id)
	if !ok {
		return refutedFact("RELEASE_LOCK", "SELECT_RELEASE_LOCK", "RELEASE_LOCK_UNDECLARED", "DECLARE_RELEASE_LOCK", id)
	}
	observed, ok := findRelease(e.observation.Releases, id)
	if !ok {
		return unknownFact("RELEASE_OBSERVATION", "OBSERVE_RELEASE_IDENTITY", "RELEASE_OBSERVATION_UNAVAILABLE", "DIRECT_MISSING", "OBSERVE_PINNED_RELEASE")
	}
	if expected.Role != observed.Role || expected.Repository != observed.Repository || expected.Tag != observed.Tag || expected.TagObjectSHA != observed.TagObjectSHA || expected.TargetCommitSHA != observed.TargetCommitSHA || expected.Draft != observed.Draft || expected.Prerelease != observed.Prerelease {
		return refutedFact("RELEASE_OBSERVATION", "VERIFY_RELEASE_IDENTITY", "RELEASE_IDENTITY_MISMATCH", "RESTORE_PINNED_RELEASE_IDENTITY", id)
	}
	for _, asset := range expected.Assets {
		observedAsset, found := findAsset(observed.Assets, asset.Kind)
		if !found {
			return unknownFact("RELEASE_ASSET", "OBSERVE_RELEASE_ASSET", "GENERATOR_CONSUMER_ASSET_UNAVAILABLE", "DIRECT_MISSING", "PUBLISH_REQUIRED_RELEASE_ASSET")
		}
		if observedAsset.Name != asset.Name || observedAsset.SHA256 != asset.SHA256 {
			return refutedFact("RELEASE_ASSET", "VERIFY_RELEASE_ASSET_IDENTITY", "RELEASE_ASSET_IDENTITY_MISMATCH", "RESTORE_PINNED_RELEASE_ASSET", id+":"+asset.Kind)
		}
		path := filepath.Join(e.root, id, asset.Name)
		actual, err := fileSHA256(path)
		if os.IsNotExist(err) {
			return unknownFact("RELEASE_ASSET", "READ_RELEASE_ASSET", "GENERATOR_CONSUMER_ASSET_UNAVAILABLE", "DIRECT_MISSING", "PUBLISH_REQUIRED_RELEASE_ASSET")
		}
		if err != nil {
			return refutedFact("RELEASE_ASSET", "READ_RELEASE_ASSET", "RELEASE_ASSET_UNREADABLE", "RESTORE_READABLE_RELEASE_ASSET", err.Error())
		}
		if actual != asset.SHA256 {
			return refutedFact("RELEASE_ASSET", "VERIFY_RELEASE_ASSET_DIGEST", "RELEASE_ASSET_DIGEST_MISMATCH", "RESTORE_PINNED_RELEASE_ASSET", id+":"+asset.Kind)
		}
	}
	return closedFact("PINNED_RELEASE_EVIDENCE_OBSERVED")
}

func (e *evaluator) independenceFact() fact {
	consumers := e.consumerLocks()
	if len(consumers) < e.denominator.MinimumIndependentConsumers {
		return unknownFact("CONSUMER_INDEPENDENCE", "COUNT_DISTINCT_CONSUMERS", "GENERATOR_CONSUMER_THRESHOLD_NOT_REACHED", "DIRECT_MISSING", "PUBLISH_ANOTHER_INDEPENDENT_CONSUMER")
	}
	seen := make(map[string]string)
	for _, consumer := range consumers {
		if previous, ok := seen[consumer.Repository]; ok {
			return refutedFact("CONSUMER_INDEPENDENCE", "BIND_DISTINCT_CONSUMER_REPOSITORIES", "GENERATOR_CONSUMERS_NOT_INDEPENDENT", "REPLACE_DUPLICATE_CONSUMER_RELEASE", previous+","+consumer.ID)
		}
		seen[consumer.Repository] = consumer.ID
	}
	return closedFact("INDEPENDENT_CONSUMER_REPOSITORIES_BOUND")
}

func (e *evaluator) sharedGeneratorFact() fact {
	generator, ok := findRelease(e.locks.Releases, "generator")
	if !ok || len(generator.Assets) != 1 {
		return refutedFact("GENERATOR_IDENTITY", "SELECT_GENERATOR_RELEASE", "GENERATOR_RELEASE_LOCK_INVALID", "RESTORE_GENERATOR_RELEASE_LOCK", "generator")
	}
	for _, consumer := range e.consumerLocks() {
		path, ok := e.assetPath(consumer, "generator-pin")
		if !ok {
			return refutedFact("GENERATOR_IDENTITY", "SELECT_GENERATOR_PIN", "GENERATOR_PIN_UNDECLARED", "DECLARE_GENERATOR_PIN", consumer.ID)
		}
		var pin generatorPin
		if err := tryReadJSON(path, &pin); err != nil {
			if os.IsNotExist(err) {
				return closedFact("GENERATOR_PIN_DEFERRED_TO_RELEASE_DEPENDENCY")
			}
			return refutedFact("GENERATOR_IDENTITY", "PARSE_GENERATOR_PIN", "GENERATOR_PIN_INVALID", "RESTORE_GENERATOR_PIN", consumer.ID)
		}
		asset := generator.Assets[0]
		if pin.Generator.Repository != generator.Repository || pin.Generator.Tag != generator.Tag || pin.Generator.TagObjectSHA != generator.TagObjectSHA || pin.Generator.TargetCommitSHA != generator.TargetCommitSHA || pin.Generator.PortableAsset.Name != asset.Name || pin.Generator.PortableAsset.SHA256 != asset.SHA256 {
			return refutedFact("GENERATOR_IDENTITY", "BIND_SHARED_GENERATOR_IDENTITY", "GENERATOR_RELEASE_IDENTITY_MISMATCH", "PIN_COMMON_GENERATOR_RELEASE", consumer.ID)
		}
	}
	return closedFact("SHARED_GENERATOR_RELEASE_IDENTITY_BOUND")
}

func (e *evaluator) reportContractFact() fact {
	for _, consumer := range e.consumerLocks() {
		var generated generationReport
		if deferred, invalid := e.readConsumerJSON(consumer, "report", &generated); deferred {
			continue
		} else if invalid {
			return refutedFact("CONSUMER_REPORT", "PARSE_GENERATION_REPORT", "GENERATOR_CONSUMER_REPORT_INVALID", "RESTORE_GENERATION_REPORT", consumer.ID)
		}
		var verified verificationReport
		if deferred, invalid := e.readConsumerJSON(consumer, "verification", &verified); deferred {
			continue
		} else if invalid {
			return refutedFact("CONSUMER_REPORT", "PARSE_VERIFICATION_REPORT", "GENERATOR_CONSUMER_VERIFICATION_INVALID", "RESTORE_VERIFICATION_REPORT", consumer.ID)
		}
		if generated.Schema != e.denominator.RequiredReportSchema || verified.Schema != e.denominator.RequiredVerificationSchema {
			return refutedFact("CONSUMER_REPORT", "BIND_REPORT_CONTRACT_MAJOR", "GENERATOR_CONSUMER_CONTRACT_MISMATCH", "RESTORE_V2_GENERATOR_CONTRACT", consumer.ID)
		}
	}
	return closedFact("GENERATOR_V2_REPORT_CONTRACT_BOUND")
}

func (e *evaluator) generationClosureFact() fact {
	for _, consumer := range e.consumerLocks() {
		var generated generationReport
		if deferred, invalid := e.readConsumerJSON(consumer, "report", &generated); deferred {
			continue
		} else if invalid {
			return refutedFact("CONSUMER_GENERATION", "PARSE_GENERATION_REPORT", "GENERATOR_CONSUMER_REPORT_INVALID", "RESTORE_CLOSED_GENERATION_REPORT", consumer.ID)
		}
		proofClosed, proofTotal := aggregateInputCounts(generated.Proofs)
		indicatorClosed, indicatorTotal := aggregateInputCounts(generated.Indicators)
		if generated.Decision != "PROJECT_GENERATED" || generated.Claim.State != closed || generated.Summary.Closed != 12 || generated.Summary.Total != 12 || generated.Summary.Unknown != 0 || generated.Summary.Refuted != 0 || proofClosed != 12 || proofTotal != 12 || indicatorClosed != 12 || indicatorTotal != 12 {
			return refutedFact("CONSUMER_GENERATION", "OBSERVE_GENERATED_PROJECT_CLOSURE", "GENERATOR_CONSUMER_REPORT_INVALID", "RESTORE_CLOSED_GENERATION_REPORT", consumer.ID)
		}
	}
	return closedFact("TWO_GENERATED_PROJECTS_CLOSED")
}

func (e *evaluator) verificationFact() fact {
	for _, consumer := range e.consumerLocks() {
		var verified verificationReport
		if deferred, invalid := e.readConsumerJSON(consumer, "verification", &verified); deferred {
			continue
		} else if invalid {
			return refutedFact("CONSUMER_VERIFICATION", "PARSE_VERIFICATION_REPORT", "GENERATOR_CONSUMER_VERIFICATION_INVALID", "RESTORE_VERIFICATION_REPORT", consumer.ID)
		}
		if verified.Decision != "GENERATION_VERIFIED" || verified.Claim.State != closed || verified.Summary.Closed != 6 || verified.Summary.Total != 6 || verified.Summary.Unknown != 0 || verified.Summary.Refuted != 0 || !verified.ManifestIdentityMatch {
			return refutedFact("CONSUMER_VERIFICATION", "OBSERVE_GENERATED_FILE_VERIFICATION", "GENERATED_FILE_VERIFICATION_INVALID", "RESTORE_GENERATED_FILE_DIGESTS", consumer.ID)
		}
	}
	return closedFact("TWO_GENERATED_FILE_SETS_VERIFIED")
}

func (e *evaluator) runtimeFact() fact {
	if e.observation.SourceRepositoryWrites != 0 {
		return refutedFact("OBSERVER_EFFECT", "OBSERVE_SOURCE_REPOSITORY_EFFECT", "SOURCE_REPOSITORY_WRITE_OBSERVED", "REMOVE_SOURCE_REPOSITORY_WRITE", fmt.Sprintf("writes=%d", e.observation.SourceRepositoryWrites))
	}
	for _, consumer := range e.consumerLocks() {
		var runtime consumerRuntime
		if deferred, invalid := e.readConsumerJSON(consumer, "runtime", &runtime); deferred {
			continue
		} else if invalid {
			return refutedFact("CONSUMER_RUNTIME", "PARSE_CONSUMER_RUNTIME", "GENERATOR_CONSUMER_RUNTIME_INVALID", "RESTORE_CONSUMER_RUNTIME", consumer.ID)
		}
		if !runtime.DeterministicReplay || runtime.Repository.Writes != 0 || runtime.Repository.BeforeDigest == "" || runtime.Repository.BeforeDigest != runtime.Repository.AfterDigest || runtime.LocalTestsRun != 0 {
			return refutedFact("CONSUMER_RUNTIME", "OBSERVE_DETERMINISTIC_READ_ONLY_RUNTIME", "GENERATOR_CONSUMER_RUNTIME_INVALID", "RESTORE_READ_ONLY_DETERMINISTIC_RUNTIME", consumer.ID)
		}
	}
	return closedFact("DETERMINISTIC_READ_ONLY_CONSUMER_RUNTIME_OBSERVED")
}

func (e *evaluator) checksumFact() fact {
	for _, consumer := range e.consumerLocks() {
		path, ok := e.assetPath(consumer, "checksums")
		if !ok {
			return refutedFact("PUBLIC_CHECKSUMS", "SELECT_CHECKSUM_ASSET", "CHECKSUM_ASSET_UNDECLARED", "DECLARE_CHECKSUM_ASSET", consumer.ID)
		}
		data, err := os.ReadFile(path)
		if os.IsNotExist(err) {
			continue
		}
		if err != nil {
			return refutedFact("PUBLIC_CHECKSUMS", "READ_CHECKSUM_ASSET", "CHECKSUM_ASSET_UNREADABLE", "RESTORE_CHECKSUM_ASSET", consumer.ID)
		}
		entries := parseChecksums(string(data))
		for _, asset := range consumer.Assets {
			if asset.Kind == "checksums" {
				continue
			}
			if entries[asset.Name] != asset.SHA256 {
				return refutedFact("PUBLIC_CHECKSUMS", "BIND_PUBLIC_CHECKSUM_EVIDENCE", "PUBLIC_CHECKSUM_MISMATCH", "RESTORE_PUBLIC_CHECKSUMS", consumer.ID+":"+asset.Name)
			}
		}
	}
	return closedFact("PUBLIC_CHECKSUM_EVIDENCE_BOUND")
}

func (e *evaluator) readConsumerJSON(consumer releaseLock, kind string, target any) (bool, bool) {
	path, ok := e.assetPath(consumer, kind)
	if !ok {
		return false, true
	}
	err := tryReadJSON(path, target)
	if os.IsNotExist(err) {
		return true, false
	}
	return false, err != nil
}

func (e *evaluator) assetPath(release releaseLock, kind string) (string, bool) {
	asset, ok := findAsset(release.Assets, kind)
	if !ok {
		return "", false
	}
	return filepath.Join(e.root, release.ID, asset.Name), true
}

func (e *evaluator) consumerLocks() []releaseLock {
	var consumers []releaseLock
	for _, release := range e.locks.Releases {
		if release.Role == "consumer" {
			consumers = append(consumers, release)
		}
	}
	return consumers
}

func (e *evaluator) observationMetrics() observations {
	consumers := e.consumerLocks()
	repositories := make([]string, 0, len(consumers))
	unique := make(map[string]struct{})
	evidenceAssets := 0
	generatedCells := 0
	verificationCells := 0
	for _, consumer := range consumers {
		repositories = append(repositories, consumer.Repository)
		unique[consumer.Repository] = struct{}{}
		for _, asset := range consumer.Assets {
			path := filepath.Join(e.root, consumer.ID, asset.Name)
			if digest, err := fileSHA256(path); err == nil && digest == asset.SHA256 {
				evidenceAssets++
			}
		}
		var generated generationReport
		if path, ok := e.assetPath(consumer, "report"); ok && tryReadJSON(path, &generated) == nil && generated.Decision == "PROJECT_GENERATED" && generated.Summary.Closed == generated.Summary.Total && generated.Summary.Unknown == 0 && generated.Summary.Refuted == 0 {
			generatedCells += generated.Summary.Closed
		}
		var verified verificationReport
		if path, ok := e.assetPath(consumer, "verification"); ok && tryReadJSON(path, &verified) == nil && verified.Decision == "GENERATION_VERIFIED" && verified.Summary.Closed == verified.Summary.Total && verified.Summary.Unknown == 0 && verified.Summary.Refuted == 0 {
			verificationCells += verified.Summary.Closed
		}
	}
	sort.Strings(repositories)
	generator, _ := findRelease(e.locks.Releases, "generator")
	return observations{
		IndependentConsumers: ratio{Observed: len(unique), Total: e.denominator.MinimumIndependentConsumers},
		EvidenceAssets:       ratio{Observed: evidenceAssets, Total: len(consumers) * e.denominator.RequiredEvidencePerConsumer},
		GeneratedCells:       ratio{Observed: generatedCells, Total: len(consumers) * 12},
		VerificationCells:    ratio{Observed: verificationCells, Total: len(consumers) * 6},
		ConsumerRepositories: repositories,
		GeneratorTag:         generator.Tag,
	}
}

func (e *evaluator) totalRepositoryWrites() int {
	writes := e.observation.SourceRepositoryWrites
	for _, consumer := range e.consumerLocks() {
		var runtime consumerRuntime
		if path, ok := e.assetPath(consumer, "runtime"); ok && tryReadJSON(path, &runtime) == nil {
			writes += runtime.Repository.Writes
		}
	}
	return writes
}

func (e *evaluator) totalLocalTests() int {
	total := 0
	for _, consumer := range e.consumerLocks() {
		var runtime consumerRuntime
		if path, ok := e.assetPath(consumer, "runtime"); ok && tryReadJSON(path, &runtime) == nil {
			total += runtime.LocalTestsRun
		}
	}
	return total
}

func resolveDependencies(direct fact, dependencies []string, byID map[string]cellResult) (fact, []string) {
	var refutedDependencies []string
	var unknownDependencies []string
	for _, id := range dependencies {
		dependency, ok := byID[id]
		if !ok {
			return refutedFact("DENOMINATOR", "RESOLVE_CELL_DEPENDENCY", "UNKNOWN_CELL_DEPENDENCY", "REPAIR_DENOMINATOR", id), []string{id}
		}
		switch dependency.State {
		case refuted:
			refutedDependencies = append(refutedDependencies, id)
		case unknown:
			unknownDependencies = append(unknownDependencies, id)
		}
	}
	if direct.State == refuted {
		return direct, nil
	}
	if len(refutedDependencies) > 0 {
		return fact{State: refuted, Stage: "DEPENDENCY", Step: "RESOLVE_CELL_DEPENDENCIES", Reason: "DEPENDENCY_REFUTED", NextOperation: "RESTORE_REFUTED_DEPENDENCY"}, refutedDependencies
	}
	if direct.State == unknown {
		return direct, nil
	}
	if len(unknownDependencies) > 0 {
		return fact{State: unknown, Stage: "DEPENDENCY", Step: "RESOLVE_CELL_DEPENDENCIES", Reason: "DEPENDENCY_BLOCKED", UnknownClass: "DEPENDENCY_BLOCKED", NextOperation: "RESOLVE_BLOCKING_DEPENDENCY"}, unknownDependencies
	}
	return direct, nil
}

func summarize(cells []cellResult) reportSummary {
	result := reportSummary{Total: len(cells)}
	for _, cell := range cells {
		switch cell.State {
		case closed:
			result.Closed++
		case unknown:
			result.Unknown++
			if cell.UnknownClass != nil && *cell.UnknownClass == "DIRECT_MISSING" {
				result.DirectMissing++
			}
			if cell.UnknownClass != nil && *cell.UnknownClass == "DEPENDENCY_BLOCKED" {
				result.DependencyBlocked++
			}
		case refuted:
			result.Refuted++
		}
	}
	return result
}

func aggregateProofs(specs []namedCountSpec, cells []cellResult) []closedTotal {
	result := make([]closedTotal, 0, len(specs))
	for _, spec := range specs {
		closedCount := 0
		for _, cell := range cells {
			if cell.Proof == spec.Choice && cell.State == closed {
				closedCount++
			}
		}
		result = append(result, closedTotal{Choice: spec.Choice, Closed: closedCount, Total: spec.Total})
	}
	return result
}

func aggregateClasses(specs []namedCountSpec, cells []cellResult) []closedTotal {
	result := make([]closedTotal, 0, len(specs))
	for _, spec := range specs {
		closedCount := 0
		for _, cell := range cells {
			if cell.IndicatorClass == spec.Class && cell.State == closed {
				closedCount++
			}
		}
		result = append(result, closedTotal{Class: spec.Class, Closed: closedCount, Total: spec.Total})
	}
	return result
}

func selectClaim(cells []cellResult) (outputClaim, string) {
	for _, state := range []string{refuted, unknown} {
		for _, cell := range cells {
			if cell.State != state {
				continue
			}
			unknownClass := cell.UnknownClass
			stage := "GENERATOR_PROMOTION"
			step := cell.Activity
			next := "RESTORE_GENERATOR_PROMOTION_EVIDENCE"
			if state == unknown {
				next = "PUBLISH_MISSING_GENERATOR_CONSUMER_EVIDENCE"
			}
			return outputClaim{
				ID:            "gooo://claim/generator-consumer-promotion/v1",
				State:         state,
				Stage:         &stage,
				Step:          &step,
				Reason:        cell.Reason,
				UnknownClass:  unknownClass,
				NextOperation: next,
				BlockedBy:     append([]string{cell.ID}, cell.BlockedBy...),
			}, map[string]string{refuted: "FAIL_CLOSED", unknown: "INCOMPLETE"}[state]
		}
	}
	return outputClaim{
		ID:            "gooo://claim/generator-consumer-promotion/v1",
		State:         closed,
		Reason:        "TWO_INDEPENDENT_GENERATOR_CONSUMERS_OBSERVED",
		NextOperation: "PUBLISH_GENERATOR_PROMOTION_OBSERVATION",
		BlockedBy:     []string{},
	}, "GENERATOR_PROMOTION_ELIGIBLE"
}

func makeIndicators(summary reportSummary, observed observations, writes, localTests int) []indicator {
	return []indicator{
		{ID: "gooo.metric.generator-promotion.independent-consumers.v1", Activity: "BindDistinctConsumerRepositories", Class: "OUTCOME", State: indicatorState(observed.IndependentConsumers.Observed >= observed.IndependentConsumers.Total), Value: observed.IndependentConsumers.Observed, Total: observed.IndependentConsumers.Total, Unit: "repositories"},
		{ID: "gooo.metric.generator-promotion.evidence-assets.v1", Activity: "ObserveLocalConsumerRelease", Class: "DRIVER", State: indicatorState(observed.EvidenceAssets.Observed == observed.EvidenceAssets.Total), Value: observed.EvidenceAssets.Observed, Total: observed.EvidenceAssets.Total, Unit: "assets"},
		{ID: "gooo.metric.generator-promotion.generated-cells.v1", Activity: "ObserveGeneratedProjectClosure", Class: "OUTCOME", State: indicatorState(observed.GeneratedCells.Observed == observed.GeneratedCells.Total), Value: observed.GeneratedCells.Observed, Total: observed.GeneratedCells.Total, Unit: "cells"},
		{ID: "gooo.metric.generator-promotion.verification-cells.v1", Activity: "ObserveGeneratedFileVerification", Class: "DRIVER", State: indicatorState(observed.VerificationCells.Observed == observed.VerificationCells.Total), Value: observed.VerificationCells.Observed, Total: observed.VerificationCells.Total, Unit: "checks"},
		{ID: "gooo.metric.generator-promotion.meta-cells.v1", Activity: "SelectGeneratorPromotionOperation", Class: "OUTCOME", State: indicatorState(summary.Closed == summary.Total), Value: summary.Closed, Total: summary.Total, Unit: "cells"},
		{ID: "gooo.metric.generator-promotion.repository-writes.v1", Activity: "ObserveDeterministicReadOnlyRuntime", Class: "GUARDRAIL", State: indicatorState(writes == 0), Value: writes, Total: 0, Unit: "writes"},
		{ID: "gooo.metric.generator-promotion.local-tests.v1", Activity: "ObserveDeterministicReadOnlyRuntime", Class: "GUARDRAIL", State: indicatorState(localTests == 0), Value: localTests, Total: 0, Unit: "executions"},
		{ID: "gooo.metric.generator-promotion.external-required-gates.v1", Activity: "SelectGeneratorPromotionOperation", Class: "GUARDRAIL", State: "SATISFIED", Value: 0, Total: 0, Unit: "gates"},
	}
}

func aggregateInputCounts(values []closedTotal) (int, int) {
	closedCount := 0
	total := 0
	for _, value := range values {
		closedCount += value.Closed
		total += value.Total
	}
	return closedCount, total
}

func parseChecksums(data string) map[string]string {
	result := make(map[string]string)
	for _, line := range strings.Split(data, "\n") {
		fields := strings.Fields(line)
		if len(fields) < 2 {
			continue
		}
		name := strings.TrimPrefix(fields[len(fields)-1], "*")
		result[filepath.Base(name)] = fields[0]
	}
	return result
}

func findRelease(values []releaseLock, id string) (releaseLock, bool) {
	for _, value := range values {
		if value.ID == id {
			return value, true
		}
	}
	return releaseLock{}, false
}

func findAsset(values []assetLock, kind string) (assetLock, bool) {
	for _, value := range values {
		if value.Kind == kind {
			return value, true
		}
	}
	return assetLock{}, false
}

func fileSHA256(path string) (string, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return "", err
	}
	digest := sha256.Sum256(data)
	return fmt.Sprintf("%x", digest), nil
}

func tryReadJSON(path string, target any) error {
	data, err := os.ReadFile(path)
	if err != nil {
		return err
	}
	return json.Unmarshal(data, target)
}

func readJSON(path string, target any) {
	if err := tryReadJSON(path, target); err != nil {
		fatalf("read %s: %v", path, err)
	}
}

func closedFact(reason string) fact {
	return fact{State: closed, Reason: reason, NextOperation: "NONE"}
}

func unknownFact(stage, step, reason, class, next string) fact {
	return fact{State: unknown, Stage: stage, Step: step, Reason: reason, UnknownClass: class, NextOperation: next}
}

func refutedFact(stage, step, reason, next string, details ...string) fact {
	return fact{State: refuted, Stage: stage, Step: step, Reason: reason, NextOperation: next, Details: details}
}

func nullable(value string) *string {
	if value == "" {
		return nil
	}
	copy := value
	return &copy
}

func indicatorState(ok bool) string {
	if ok {
		return "SATISFIED"
	}
	return "UNSATISFIED"
}

func fatalf(format string, args ...any) {
	fmt.Fprintf(os.Stderr, format+"\n", args...)
	os.Exit(1)
}
