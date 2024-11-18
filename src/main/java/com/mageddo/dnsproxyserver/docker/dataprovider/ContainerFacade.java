package com.mageddo.dnsproxyserver.docker.dataprovider;

import com.github.dockerjava.api.command.InspectContainerResponse;
import com.github.dockerjava.api.model.Container;

import java.util.List;
import java.util.stream.Stream;

public interface ContainerFacade {

  Container findById(String containerId);

  List<Container> findActiveContainers();

  InspectContainerResponse inspect(String id);

  InspectContainerResponse safeInspect(String id);

  Stream<InspectContainerResponse> inspectFilteringValidContainers(List<Container> containers);
}
