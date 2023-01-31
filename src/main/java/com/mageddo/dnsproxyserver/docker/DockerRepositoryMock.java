package com.mageddo.dnsproxyserver.docker;

import lombok.AllArgsConstructor;

import javax.inject.Inject;
import javax.inject.Singleton;
import java.util.Objects;

@Singleton
@AllArgsConstructor(onConstructor = @__({@Inject}))
public class DockerRepositoryMock implements DockerRepository {
  @Override
  public String findHostIp(String host) {
    if (Objects.equals("acme.com", host)) {
      return "192.168.0.1";
    }
    return null;
  }
}
