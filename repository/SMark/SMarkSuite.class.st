"
A Benchmark Suite is a set of benchmarks and it knows what exactly needs to be executed.
However, it does not really know how to execute it.
It knows all the magic, that is, how to set up and tear down the environment for the benchmarks, but does not have the knowledge of how many iterations need to be done and how to evaluate any results that might be produced.

Please see also SMarkHarness, which is the main class relevant for users to execute benchmarks with SMark.

Usage:

Choose a suite (i.e. one of my subclasses) and use the class-side #run or run: messages.

To get an example print the result of the following expression:
	
	SMarkCompiler run: 10
	
	SMarkLoops runOnly: #benchArrayAccess

"
Class {
	#name : #SMarkSuite,
	#superclass : #Object,
	#instVars : [
		'runner',
		'selectedBenchmarks'
	],
	#category : #SMark
}

{ #category : #benchmarking }
SMarkSuite class >> benchmarkForSelector: aSelector [

	"Returns a single benchmark for the corresponding selector"

  ^ SMarkBenchmark new
		suite: self new;
		selector: aSelector;
		yourself
]

{ #category : #benchmarking }
SMarkSuite class >> benchmarkParameters [

  ^ ParametrizedTestMatrix new
]

{ #category : #defaults }
SMarkSuite class >> defaultProblemSize [
	^ nil
]

{ #category : #defaults }
SMarkSuite class >> defaultRunner [
	^ self onCog: [SMarkCogRunner]
	       else:  [SMarkRunner]
]

{ #category : #benchmarking }
SMarkSuite class >> isAbstractClass [
	"This is a hack that is necessary in Squeak since it does not provide #isAbstractClass.
	 Actually this class is supposed to be abstract, but well, inheritance..."
	
	^ false
]

{ #category : #'platform support' }
SMarkSuite class >> onCog: cogSpecificBlock else: general [
	^ (Smalltalk vm isRunningCogit)
		ifTrue:  [cogSpecificBlock value]
		ifFalse: [general value]
]

{ #category : #profiling }
SMarkSuite class >> profile: aSelector [
	^ self profileRunner 
		execute: self new selector: aSelector.
]

{ #category : #profiling }
SMarkSuite class >> profile: aSelector iterations: nIterations [
	^ self profileRunner 
		execute: self new selector: aSelector iterations: nIterations.
]

{ #category : #profiling }
SMarkSuite class >> profileAll [
	^ self profileRunner 
		execute: self new.
]

{ #category : #profiling }
SMarkSuite class >> profileRunner [
	^ SMarkProfileRunner
]

{ #category : #benchmarking }
SMarkSuite class >> run [
	"Execute the suite one time."
	^ self defaultRunner execute: self new.
]

{ #category : #benchmarking }
SMarkSuite class >> run: nIterations [
	"Execute the suite a given number of iterations."
	
	^ self defaultRunner execute: self new with: nIterations.
]

{ #category : #benchmarking }
SMarkSuite class >> runOnly: aSelector [
  "aSelector should refer to a benchmark method.
   Example:
     SMarkLoops runOnly: #benchFloatLoop
  "
  ^ self defaultRunner execute: (self new runOnly: aSelector)
]

{ #category : #benchmarking }
SMarkSuite class >> runOnly: aSelector iterations: anInteger [
	"Execute only the bench name aSelector from the suite."
	
	^ self defaultRunner execute: (self new runOnly: aSelector) with: anInteger
]

{ #category : #helper }
SMarkSuite >> benchmarkNameForSelector: selector [

	"Extracts the actual name of the benchmark from the selector"

	| benchName currentParams stream |
	benchName := (selector beginsWith: #bench)
		ifTrue: [ selector copyFrom: 6 to: selector size ]
		ifFalse: [ selector asSymbol ].
	currentParams := self currentBenchmarkParameters.
	currentParams ifEmpty: [ ^ benchName ] ifNotEmpty: [
		stream := TextStream on: String new.
		currentParams printElementsOn: stream.
		^ benchName, stream contents ]
]

{ #category : #running }
SMarkSuite >> cleanUpInstanceVariables [
	"Make sure all variables that are 'user variables' get cleaned"
	
	(self class allInstVarNames copyWithoutAll: self instanceVariablesToPreserve) do: [ :name |
		self instVarNamed: name put: nil ]
]

{ #category : #benchmarking }
SMarkSuite >> currentBenchmarkParameters [ 

	^ (self class benchmarkParameters selectors collect: [ :selector | (selector -> (self instVarNamed: selector)) ]) asDictionary
]

{ #category : #running }
SMarkSuite >> instanceVariablesToPreserve [
	^ { #runner. self paramInstanceVariables } flattened
]

{ #category : #accessing }
SMarkSuite >> paramInstanceVariables [

	^ self class benchmarkParameters selectors.
]

{ #category : #running }
SMarkSuite >> performBenchmarkSelector: aSelector [

	^ self perform: aSelector
]

{ #category : #benchmarking }
SMarkSuite >> performBenchmarks [

	| potentialBenchmarkSelectors |
	selectedBenchmarks
		ifNotNil: [ potentialBenchmarkSelectors := selectedBenchmarks ]
		ifNil: [ potentialBenchmarkSelectors := self class allSelectors ].

	potentialBenchmarkSelectors do: [ :selector | 
		(self shouldRunSelector: selector) ifTrue: [ 
			runner performBenchmark: selector ] ]
]

{ #category : #benchmarking }
SMarkSuite >> performCustomSelector: aSelector with: aPrefix [
	| customSelector |
	customSelector := (aPrefix, aSelector capitalized) asSymbol.
	(self respondsTo: customSelector) ifTrue: [ 
		self perform: customSelector].
]

{ #category : #benchmarking }
SMarkSuite >> problemSize [
	<omniUnenforced> "Hint for the OMOP that it is part of the meta infrastructure"
	runner             ifNil: [^ self class defaultProblemSize].
	runner problemSize ifNil: [^ self class defaultProblemSize].
	^ runner problemSize
]

{ #category : #benchmarking }
SMarkSuite >> processResult: anObject withTimer: aSMarkTimer [
	"subclass responsability. You can verify your results here, or do things with the timer."
	^self.
]

{ #category : #benchmarking }
SMarkSuite >> run [
	"Executes all the benchmarks in the suite, 
	 coordinating with the runner when necessary"
	
	| expandedParamMatrix |
	
	expandedParamMatrix := self class benchmarkParameters expandMatrix.

	expandedParamMatrix ifEmpty: [^ self performBenchmarks].

	expandedParamMatrix do: [ :expandedParameters |
		expandedParameters do: [ :param | self instVarNamed: param selector put: param valuable ].
		self performBenchmarks.
	].
]

{ #category : #benchmarking }
SMarkSuite >> runBenchmark: aSelector [
	
	[self setUp.
	 self performCustomSelector: aSelector with: #setUp.
	 runner timedBenchmarkExecution: aSelector] ensure: [
		self performCustomSelector: aSelector with: #tearDown.
		self tearDown.
		self cleanUpInstanceVariables]
]

{ #category : #benchmarking }
SMarkSuite >> runOnly: aSymbol [
	selectedBenchmarks := IdentitySet newFrom: { aSymbol }.
]

{ #category : #accessing }
SMarkSuite >> runner [
	^ runner
]

{ #category : #accessing }
SMarkSuite >> runner: aRunner [
	runner := aRunner.
]

{ #category : #benchmarking }
SMarkSuite >> selectedBenchmarks [
	^ selectedBenchmarks
]

{ #category : #running }
SMarkSuite >> setUp [
	"It is the subclass' responsibility to set up the necessary environment for a benchmark"
	^ self
]

{ #category : #testing }
SMarkSuite >> shouldRunSelector: selector [
	"Tells whether the given selector is in the form bench*, and thus is a benchmark that should be executed."
	
	(selector includes: $:) ifTrue: [ ^ false ].
	^ selector beginsWith: #bench
]

{ #category : #running }
SMarkSuite >> tearDown [
	"It is the subclass' responsibility to clean up the environment after a benchmark"
	^ self
]
