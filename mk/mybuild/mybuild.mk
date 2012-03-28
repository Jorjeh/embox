#
#   Date: Feb 10, 2012
# Author: Eldar Abusalimov
#

ifndef __mybuild_mybuild_mk
__mybuild_mybuild_mk := 1

include mk/mybuild/myfile-resource.mk

# Constructor args:
#   1. Configuration resource set.
define class-Mybuild
	$(super IssueReceiver)

	$(property-field configResourceSet : ResourceSet,$1)

	$(map moduleInstanceStore... : BuildModuleInstance)

	# Args:
	$(method createBuild,
		$(for build <-$(new BuildBuild),
			$(set build->modules,
				$(invoke getBuildModules))
			$(build)))

	$(method getBuildModules,
		$(with \
			$(for \
				configResSet <- $(get configResourceSet),
				config <- $(get configResSet->resources),
				cfgFileContent <- $(get config->contentsRoot),
				cfgConfiguration <- $(firstword $(get cfgFileContent->configurations)), #FIXME
				cfgInclude <- $(get cfgConfiguration->includes),
				module <- $(get cfgInclude->module),

				$(if $(invoke moduleInstanceHas,$(module)),,
					$(invoke moduleInstanceClosure,$(module)))

				$(for moduleInst <- $(invoke moduleInstance,$(module)),
					$(set moduleInst->includeMember,$(cfgInclude)))),

			$(if $(strip $(or \
						$(invoke superSetDeps,$1),
						$(invoke checkResolve,$1),
						$(invoke optionBind,$1))),
				$(invoke printIssues),
				$1)))

	$(method superSetDeps,
		$(silent-for \
			inst <- $1,
		   	mod <- $(get inst->type),
			super <- $(get mod->allSuperTypes),
			superInst <- $(invoke moduleInstance,$(super)),
			$(set+ superInst->depends,$(inst))))


	$(method getInstDepsOrigin,
		$(for \
			inst <- $1,
			instType <- $(get inst->type),
			$(if $(get inst->includeMember),
				$(for \
					includeMember <- $(get inst->includeMember),
					resource <- $(get includeMember->eResource),
						$(\n)$(\n)$(\t)$(get resource->fileName):
							$(get includeMember->origin) \
							$(get instType->qualifiedName)),
					$(\n)$(\n)$(\t)(As dependence)::
						$(get instType->qualifiedName))))


	# Args:
	#  1. List of moduleInstance's
	$(method checkResolve,
		$(strip
			$(for inst <- $1,
				instType <- $(get inst->type),
				isAbstr<-$(get instType->isAbstract),
				$(if $(singleword $(get inst->depends)),,#Not single realization, error
					$(if $(get inst->depends),
						$(invoke addIssues,$(new InstantiateIssue,,error,,
							Multiplie abstract realization: $(get instType->qualifiedName)
								$(invoke getInstDepsOrigin,$(get inst->depends)))),
						$(invoke addIssues,$(new InstantiateIssue,,error,,
							No abstract realization: $(get instType->qualifiedName))))

					$(inst)))
			))

	# Args:
	#  1. List of moduleInstance's
	$(method optionBind,
		$(for \
			modInst <- $1,
			mod <- $(get modInst->type),
			opt<-$(get mod->allOptions),
			optValue <- $(or $(if $(get modInst->includeMember),# if module was explicitly enabled
										# from configs and probably has
										# config option bindings
						$(invoke findOptValue,$(opt),
							$(get $(get modInst->includeMember).optionBindings))),
					 $(get opt->defaultValue),
					 Error),

			$(if $(eq $(optValue),Error),
				$(invoke addIssues,$(new InstantiateIssue,
					$(for includeMember <- $(get modInst->includeMember),
						$(get includeMember->eResource)),
					warning,
					$(for includeMember <- $(get modInst->includeMember),
						$(get includeMember->origin)),
					Couldn't bind option $(get opt->name) in module \
						$(get mod->qualifiedName) to a value))
					,

				$(silent-for optInst <- $(new BuildOptionInstance),
					$(set optInst->option,$(opt))
					$(set optInst->optionValue,$(optValue))
					$(set+ modInst->options,$(optInst))))))

	$(method findOptValue,
		$(for \
			opt <- $1,
			optName <- $(get opt->name),
			optBinding <- $2,
			optBindOpt <- $(get optBinding->option),
			optBindName <- $(get optBindOpt->name),
			optBindVal <- $(get optBinding->optionValue),
			$(if $(and $(eq $(optName),$(optBindName)),
					$(invoke opt->validateValue,$(optBindVal))),
				$(optBindVal))))


	# Args:
	#  1. MyModule instance
	# Return:
	#  ModuleInstance instance
	$(method moduleInstance,
		$(for mod <- $1,
			$(or $(invoke moduleInstanceHas,$(mod)),
				$(for moduleInstance <-
					$(new BuildModuleInstance,$(mod)),

					$(set moduleInstance->type,$(mod))

					$(map-set moduleInstanceStore/$(mod),
						$(moduleInstance))

					$(moduleInstance)))))

	# Args:
	#  1. MyModule instance
	# Return:
	#  ModuleInstance on positive
	#  None on negative
	$(method moduleInstanceHas,
		$(map-get moduleInstanceStore/$1))

	# Args:
	#  1. MyModule object instance, that not presented in build
	# Return:
	#  List of ModuleInstance for module, that have no reperesents yet
	$(method moduleInstanceClosure,
			$(for thisInst<-$(invoke moduleInstance,$1),
				$(thisInst) \
				$(for \
					mod <- $1,
					dep <- $(get mod->depends),
					was <- was$(invoke moduleInstanceHas,$(dep)),
					$(for depInst <- $(invoke moduleInstance,$(dep)),
						$(if $(filter $(depInst),$(get thisInst->depends)),,
							$(set+ thisInst->depends,$(depInst))))
					$(if $(filter was,$(was)),
						$(invoke moduleInstanceClosure,$(dep))))))

endef

define mybuild_create_build
	$(invoke $(new Mybuild,$(__config_resource_set)).createBuild)
endef

define printInstances
		$(strip $(for buildBuild<-$1,
			inst<-$(get buildBuild->modules),
			$(warning $(get $(strip $(get inst->type)).qualifiedName))
			$(warning Deps:)
			$(for dep <- $(get inst->depends),
				$(warning $(\t)$(get $(get dep->type).qualifiedName)))
			$(warning Opts:)
			$(for opt <- $(get $(get inst->type).allOptions),
				val <-$(warning $(\t)$(get opt->name))$(get opt->defaultValue),
				$(warning $(\t)$(\t)DefVal : $(get val->value)))
			$(warning OptInsts:)
			$(for optInst <- $(get inst->options),
				opt <- $(get optInst->option),
				val <-$(get optInst->optionValue),
				$(warning $(\t)$(get opt->name) : $(get val->value)))
			$(warning $(\n)$(\n))))
endef

define listInstances
		$(strip $(for buildBuild<-$1,
			$(get buildBuild->modules)))
endef

define class-InstantiateIssue
	$(super BaseIssue,$(value 1),$(value 2),$(value 3),$(value 4))

endef

$(def_all)

endif # __mybuild_mybuild_mk
